<template>
  <div class="messaging-page">
    <div class="header">
      <button @click="$router.back()" class="back-button">← Back</button>
      <h2>Message Seller</h2>
      <button @click="exitDemo" class="exit-demo-button" data-marker="exit-demo">Exit Demo</button>
    </div>
    <div v-if="loading" class="loading">Loading conversation...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else class="messaging-container">
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
import { clearToken, enterDemoUrl } from '../lib/demoSession.js';

// Simple JWT decode (no verification needed for demo)
function decodeJWT(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = JSON.parse(atob(parts[1]));
    return payload;
  } catch {
    return null;
  }
}

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
      error: null,
      sending: false,
      threadId: null,
      userId: null,
    };
  },
  async mounted() {
    await this.initializeMessaging();
  },
  methods: {
    async initializeMessaging() {
      try {
        // Get user ID from JWT token
        const token = localStorage.getItem('demo_auth_token');
        if (!token) {
          this.error = 'Not authenticated. Please login first.';
          this.loading = false;
          return;
        }

        const payload = decodeJWT(token);
        if (!payload || !payload.sub) {
          this.error = 'Invalid token. Please login again.';
          this.loading = false;
          return;
        }
        this.userId = payload.sub;

        // Get or create thread (upsert ensures thread exists)
        await this.ensureThread();

        // Load messages (by-context, will also set threadId from response)
        await this.loadMessages();
        this.loading = false;
      } catch (err) {
        this.error = err.message;
        this.loading = false;
      }
    },
    async ensureThread() {
      const messagingBaseUrl = '/api/messaging';
      const token = localStorage.getItem('demo_auth_token');
      
      try {
        // Upsert thread for this listing
        const response = await fetch(`${messagingBaseUrl}/api/v1/threads/upsert`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
            'messaging-api-key': 'dev-messaging-key',
          },
          body: JSON.stringify({
            context_type: 'listing',
            context_id: this.id,
            participants: [
              { type: 'user', id: this.userId },
            ],
          }),
        });

        if (!response.ok) {
          // Read error response body for better error message
          let errorText = `HTTP ${response.status}`;
          try {
            const errorData = await response.json();
            if (errorData.message) errorText += `: ${errorData.message}`;
            else if (errorData.error) errorText += `: ${errorData.error}`;
          } catch {
            // If response is not JSON, use status text
            errorText += `: ${response.statusText}`;
          }
          throw new Error(`Failed to create/get thread (${errorText})`);
        }

        const data = await response.json();
        this.threadId = data.thread_id;
      } catch (err) {
        throw new Error('Failed to initialize thread: ' + err.message);
      }
    },
    async loadMessages() {
      const messagingBaseUrl = '/api/messaging';
      const token = localStorage.getItem('demo_auth_token');

      try {
        // Use by-context endpoint (more reliable than by-id)
        const response = await fetch(`${messagingBaseUrl}/api/v1/threads/by-context?context_type=listing&context_id=${this.id}`, {
          headers: {
            'Authorization': `Bearer ${token}`,
            'messaging-api-key': 'dev-messaging-key',
          },
        });

        if (!response.ok) {
          // Read error response body for better error message
          let errorText = `HTTP ${response.status}`;
          try {
            const errorData = await response.json();
            if (errorData.message) errorText += `: ${errorData.message}`;
            else if (errorData.error) errorText += `: ${errorData.error}`;
          } catch {
            errorText += `: ${response.statusText}`;
          }
          throw new Error(`Failed to load messages (${errorText})`);
        }

        const data = await response.json();
        // Store thread_id from response for sendMessage
        if (data.thread_id) {
          this.threadId = data.thread_id;
        }
        this.messages = data.messages || [];
      } catch (err) {
        throw new Error('Failed to load messages: ' + err.message);
      }
    },
    async sendMessage() {
      if (!this.newMessage.trim() || !this.threadId || !this.userId || this.sending) return;

      this.sending = true;
      const messageBody = this.newMessage.trim();
      this.newMessage = '';

      const messagingBaseUrl = '/api/messaging';
      const token = localStorage.getItem('demo_auth_token');

      try {
        const response = await fetch(`${messagingBaseUrl}/api/v1/threads/${this.threadId}/messages`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
            'messaging-api-key': 'dev-messaging-key',
          },
          body: JSON.stringify({
            sender_type: 'user',
            sender_id: this.userId,
            body: messageBody,
          }),
        });

        if (!response.ok) {
          // Read error response body for better error message
          let errorText = `HTTP ${response.status}`;
          try {
            const errorData = await response.json();
            if (errorData.message) errorText += `: ${errorData.message}`;
            else if (errorData.error) errorText += `: ${errorData.error}`;
          } catch {
            errorText += `: ${response.statusText}`;
          }
          throw new Error(`Failed to send message (${errorText})`);
        }

        // Reload messages
        await this.loadMessages();
      } catch (err) {
        this.error = 'Failed to send message: ' + err.message;
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
    exitDemo() {
      clearToken();
      window.location.href = enterDemoUrl;
    },
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

.exit-demo-button {
  padding: 0.5rem 1rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  background: #f5f5f5;
  color: #333;
  cursor: pointer;
  font-size: 0.9rem;
}

.exit-demo-button:hover {
  background: #e5e5e5;
}

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

