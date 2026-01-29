<template>
  <div class="messaging-page">
    <div class="header">
      <button @click="$router.back()" class="back-button">← Back</button>
      <h2>Message Seller</h2>
    </div>
    <div v-if="loading" class="loading">Loading conversation...</div>
    <div v-else-if="fatalError" class="error">
      <div>{{ fatalError }}</div>
      <button class="retry-button" @click="initializeMessaging">Retry</button>
    </div>
    <div v-else class="messaging-container">
      <div v-if="inlineError" class="error inline-error">{{ inlineError }}</div>
      <div class="messages-list">
        <div v-if="messages.length === 0" class="no-messages">No messages yet. Start the conversation!</div>
        <div
          v-for="message in messages"
          :key="message.id"
          :class="['message', message.sender_type === 'user' ? 'message-user' : 'message-other']"
        >
          <div class="message-body">{{ message.body }}</div>
          <div class="message-time">{{ formatTime(message.created_at) }}</div>
        </div>
      </div>
      <div class="message-input">
        <textarea
          v-model="newMessage"
          placeholder="Type your message..."
          rows="3"
          @keydown.enter.exact.prevent="sendMessage"
        ></textarea>
        <button @click="sendMessage" :disabled="!newMessage.trim() || sending" class="send-button">
          {{ sending ? 'Sending...' : 'Send' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import { getToken, getUserId, clearSession } from '../lib/session.js';
import { messagingUpsertThread, messagingGetThreadByContext, messagingSendMessage } from '../api/client.js';

export default {
  name: 'MessagingPage',
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      messages: [],
      newMessage: '',
      loading: true,
      fatalError: null,
      inlineError: null,
      sending: false,
      threadId: null,
      userId: null,
    };
  },
  async mounted() {
    await this.initializeMessaging();
  },
  methods: {
    handleAuthExpired() {
      clearSession();
      this.$router.push('/login?reason=expired');
    },
    async initializeMessaging() {
      try {
        this.loading = true;
        this.fatalError = null;
        this.inlineError = null;

        // Get user ID from JWT token
        const token = getToken();
        if (!token) {
          this.fatalError = 'Not authenticated. Please login first.';
          return;
        }

        const uid = getUserId();
        if (!uid) {
          this.fatalError = 'Invalid token. Please login again.';
          return;
        }
        this.userId = uid;

        // Get or create thread (upsert ensures thread exists)
        await this.ensureThread();

        // Load messages (by-context, will also set threadId from response)
        await this.loadMessages();
      } catch (err) {
        if (err?.status === 401) {
          this.handleAuthExpired();
          return;
        }
        this.fatalError = err?.message || String(err);
      } finally {
        this.loading = false;
      }
    },
    async ensureThread() {
      try {
        // Upsert thread for this listing
        const data = await messagingUpsertThread({
          contextType: 'listing',
          contextId: this.id,
          participants: [{ type: 'user', id: this.userId }],
        });
        this.threadId = data?.thread_id || null;
        if (!this.threadId) {
          throw new Error('Missing thread_id in upsert response');
        }
      } catch (err) {
        if (err?.status === 401) {
          this.handleAuthExpired();
          return;
        }
        throw new Error('Failed to initialize thread: ' + err.message);
      }
    },
    async loadMessages() {
      try {
        // Use by-context endpoint (more reliable than by-id)
        const data = await messagingGetThreadByContext({ contextType: 'listing', contextId: this.id });
        // Store thread_id from response for sendMessage
        if (data.thread_id) {
          this.threadId = data.thread_id;
        }
        this.messages = data.messages || [];
      } catch (err) {
        if (err?.status === 401) {
          this.handleAuthExpired();
          return;
        }
        throw new Error('Failed to load messages: ' + err.message);
      }
    },
    async sendMessage() {
      if (!this.newMessage.trim() || !this.threadId || !this.userId || this.sending) return;

      this.sending = true;
      this.inlineError = null;
      const messageBody = this.newMessage.trim();
      this.newMessage = '';

      try {
        await messagingSendMessage(this.threadId, {
          senderType: 'user',
          senderId: this.userId,
          body: messageBody,
        });
        await this.loadMessages();
      } catch (err) {
        if (err?.status === 401) {
          this.handleAuthExpired();
          return;
        }
        this.inlineError = 'Failed to send message: ' + (err?.message || String(err));
        // Restore message on error
        this.newMessage = messageBody;
      } finally {
        this.sending = false;
      }
    },
    formatTime(timestamp) {
      if (!timestamp) return '';
      const date = new Date(timestamp);
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    },
    // WP-74: Removed exit method
  },
};
</script>

<style scoped>
.messaging-page {
  max-width: 800px;
  margin: 0 auto;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
}

/* WP-74: Removed exit button styles */

.back-button {
  padding: 0.5rem 1rem;
  margin-right: 1rem;
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.back-button:hover {
  background: #e5e5e5;
}

.loading {
  padding: 1rem;
  color: #666;
}

.error {
  padding: 1rem;
  color: #b00020;
  background: #fff5f5;
  border: 1px solid #ffd5d5;
  border-radius: 6px;
}

.inline-error {
  margin: 0.75rem;
}

.retry-button {
  margin-top: 0.75rem;
  padding: 0.5rem 0.9rem;
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
}

.messaging-container {
  display: flex;
  flex-direction: column;
  height: 600px;
  border: 1px solid #ddd;
  border-radius: 8px;
  background: white;
}

.messages-list {
  flex: 1;
  overflow-y: auto;
  padding: 1rem;
}

.no-messages {
  text-align: center;
  color: #666;
  padding: 2rem;
}

.message {
  margin-bottom: 1rem;
  padding: 0.75rem;
  border-radius: 8px;
  max-width: 70%;
}

.message-user {
  background: #0066cc;
  color: white;
  margin-left: auto;
  text-align: right;
}

.message-other {
  background: #f0f0f0;
  color: #333;
}

.message-body {
  margin-bottom: 0.25rem;
  word-wrap: break-word;
}

.message-time {
  font-size: 0.75rem;
  opacity: 0.7;
}

.message-input {
  padding: 1rem;
  border-top: 1px solid #ddd;
  display: flex;
  gap: 0.5rem;
}

.message-input textarea {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-family: inherit;
  font-size: 1rem;
  resize: none;
}

.send-button {
  padding: 0.75rem 1.5rem;
  background: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
}

.send-button:hover:not(:disabled) {
  background: #0052a3;
}

.send-button:disabled {
  background: #ccc;
  cursor: not-allowed;
}
</style>

