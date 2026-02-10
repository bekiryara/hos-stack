<template>
  <div class="messaging-page">
    <div class="header">
      <button @click="$router.back()" class="back-button">← Back</button>
      <h2>{{ headerTitle }}</h2>
      <span v-if="threadId" class="thread-id-debug">Thread: {{ threadId }}</span>
    </div>
    <div v-if="loading" class="loading">Loading conversation...</div>
    <div v-else-if="fatalError" class="error">
      <div>{{ fatalError }}</div>
      <button class="retry-button" @click="initializeMessaging">Retry</button>
    </div>
    <div v-else class="messaging-container">
      <div v-if="inlineError" class="error inline-error">{{ inlineError }}</div>
      <div
        ref="messagesList"
        class="messages-list"
        @scroll="handleMessagesScroll"
      >
        <div v-if="messages.length === 0" class="no-messages">No messages yet. Start the conversation!</div>
        <div
          v-for="message in messages"
          :key="message.id"
          :class="['message', isMine(message) ? 'message-user' : 'message-other']"
        >
          <div class="message-body">{{ message.body }}</div>
          <div class="message-time">{{ formatTime(message.created_at) }}</div>
        </div>
        <div ref="bottomAnchor" class="bottom-anchor"></div>
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
      <button
        v-if="unseenCount > 0 && !isAtBottom"
        class="new-messages-button"
        @click="jumpToBottom"
      >
        {{ unseenCount }} new message{{ unseenCount === 1 ? '' : 's' }} ↓
      </button>
    </div>
  </div>
</template>

<script>
import { getToken, getUserId, getActiveTenantId, clearSession } from '../lib/session.js';
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
      mode: 'customer', // 'customer' | 'firm'
      senderType: 'user',
      senderId: null,
      // Realtime (WebSocket) - best-effort; falls back to HTTP refresh
      ws: null,
      wsReconnectTimer: null,
      wsReconnectAttempts: 0,
      // WhatsApp-like scroll behavior
      isAtBottom: true,
      unseenCount: 0,
      didInitialScroll: false,
    };
  },
  computed: {
    headerTitle() {
      return this.mode === 'firm' ? 'Reply to Customer' : 'Message Seller';
    },
  },
  async mounted() {
    await this.initializeMessaging();
  },
  beforeUnmount() {
    this.stopRealtime();
  },
  methods: {
    getMessagesListEl() {
      return this.$refs?.messagesList || null;
    },
    getBottomAnchorEl() {
      return this.$refs?.bottomAnchor || null;
    },
    computeIsAtBottom() {
      const el = this.getMessagesListEl();
      if (!el) return true;
      const thresholdPx = 40;
      const distance = el.scrollHeight - (el.scrollTop + el.clientHeight);
      return distance <= thresholdPx;
    },
    handleMessagesScroll() {
      const atBottom = this.computeIsAtBottom();
      this.isAtBottom = atBottom;
      if (atBottom) this.unseenCount = 0;
    },
    scrollToBottom({ behavior = 'auto' } = {}) {
      const anchor = this.getBottomAnchorEl();
      if (!anchor) return;
      try {
        anchor.scrollIntoView({ behavior, block: 'end' });
      } catch {
        // ignore
      }
    },
    jumpToBottom() {
      this.unseenCount = 0;
      this.isAtBottom = true;
      this.scrollToBottom({ behavior: 'smooth' });
    },
    afterMessagesChanged({ forceScroll = false } = {}) {
      const shouldScroll = forceScroll || this.isAtBottom;
      this.$nextTick(() => {
        if (shouldScroll) this.scrollToBottom({ behavior: forceScroll ? 'smooth' : 'auto' });
      });
    },
    isMine(message) {
      return message && message.sender_type === this.senderType && String(message.sender_id) === String(this.senderId);
    },
    handleAuthExpired() {
      clearSession();
      this.$router.push('/login?reason=expired');
    },
    async initializeMessaging() {
      try {
        this.loading = true;
        this.fatalError = null;
        this.inlineError = null;

        const token = getToken();
        if (!token) {
          this.fatalError = 'Not authenticated. Please login first.';
          return;
        }

        this.mode = this.$route.query.as === 'firm' ? 'firm' : 'customer';

        if (this.mode === 'customer') {
          const uid = getUserId();
          if (!uid) {
            this.fatalError = 'Invalid token. Please login again.';
            return;
          }
          this.userId = uid;
          this.senderType = 'user';
          this.senderId = uid;
        } else {
          const tenantId = getActiveTenantId();
          if (!tenantId) {
            this.fatalError = 'Active firm required. Please select a firm from Account.';
            this.$router.replace({ path: '/account', query: { reason: 'firm_required' } }).catch(() => {});
            return;
          }
          this.senderType = 'tenant';
          this.senderId = tenantId;
        }

        await this.ensureThread();
        await this.loadMessages();
        this.startRealtime();
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
      const listingTenantId = this.$route.query.tenant_id || null;
      let participants = [];
      if (this.mode === 'customer') {
        participants = [{ type: 'user', id: this.senderId }];
        if (listingTenantId) {
          participants.push({ type: 'tenant', id: listingTenantId });
        }
      } else {
        participants = [{ type: 'tenant', id: this.senderId }];
      }

      const data = await messagingUpsertThread({
        contextType: 'listing',
        contextId: this.id,
        participants,
      });
      this.threadId = data?.thread_id || null;
      if (!this.threadId) {
        throw new Error('Missing thread_id in upsert response');
      }
    },
    async loadMessages() {
      try {
        const prevLastId = this.messages?.length ? this.messages[this.messages.length - 1]?.id : null;
        // Use by-context endpoint (more reliable than by-id)
        const data = await messagingGetThreadByContext({ contextType: 'listing', contextId: this.id });
        // Store thread_id from response for sendMessage
        if (data.thread_id) {
          this.threadId = data.thread_id;
        }
        this.messages = data.messages || [];
        const nextLastId = this.messages?.length ? this.messages[this.messages.length - 1]?.id : null;

        // Initial load: always jump to bottom.
        if (!this.didInitialScroll) {
          this.didInitialScroll = true;
          this.isAtBottom = true;
          this.unseenCount = 0;
          this.afterMessagesChanged({ forceScroll: true });
          return;
        }

        // Subsequent refresh: only scroll if user is at bottom; otherwise show "new messages" hint.
        if (!this.isAtBottom && nextLastId && nextLastId !== prevLastId) {
          this.unseenCount = Math.max(1, (this.unseenCount || 0) + 1);
        }
        this.afterMessagesChanged({ forceScroll: false });
      } catch (err) {
        if (err?.status === 401) {
          this.handleAuthExpired();
          return;
        }
        throw new Error('Failed to load messages: ' + err.message);
      }
    },
    buildWsUrl() {
      const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
      const host = window.location.host;
      const apiKey = import.meta.env.VITE_MESSAGING_API_KEY || 'dev-messaging-key';
      return `${proto}://${host}/api/messaging/ws?api_key=${encodeURIComponent(apiKey)}`;
    },
    startRealtime() {
      try {
        // Best-effort: do nothing if not in browser or missing thread
        if (typeof window === 'undefined') return;
        if (!this.threadId) return;

        // Avoid duplicate connections
        if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
          return;
        }

        const url = this.buildWsUrl();
        const ws = new WebSocket(url);
        this.ws = ws;

        ws.onopen = () => {
          this.wsReconnectAttempts = 0;
          try {
            ws.send(JSON.stringify({ action: 'subscribe', thread_id: this.threadId }));
          } catch {
            // ignore
          }
        };

        ws.onmessage = async (evt) => {
          let data;
          try {
            data = JSON.parse(String(evt.data));
          } catch {
            return;
          }

          if (data?.type === 'message:new' && data?.thread_id && data?.message) {
            const msg = data.message;
            const exists = this.messages.some((m) => m && m.id === msg.id);
            if (!exists) {
              this.messages.push(msg);
              const isSelf = this.isMine(msg);
              if (!this.isAtBottom && !isSelf) {
                this.unseenCount = Math.max(1, (this.unseenCount || 0) + 1);
              }
              // Scroll only if user is at bottom (or message is ours).
              this.afterMessagesChanged({ forceScroll: isSelf });
            }
            return;
          }

          // If we got an error from server, silently fall back to HTTP
          if (data?.type === 'error') {
            try { ws.close(); } catch {}
            return;
          }
        };

        ws.onclose = () => {
          // Only reconnect if this is the active socket
          if (this.ws === ws) {
            this.ws = null;
            this.scheduleRealtimeReconnect();
          }
        };

        ws.onerror = () => {
          // Errors are handled via close + reconnect
        };
      } catch {
        // ignore (fallback to HTTP)
      }
    },
    scheduleRealtimeReconnect() {
      if (this.wsReconnectTimer) return;
      // Exponential backoff up to 15s
      const attempt = Math.max(0, this.wsReconnectAttempts || 0);
      const delayMs = Math.min(15000, 1000 * Math.pow(2, attempt));
      this.wsReconnectAttempts = attempt + 1;

      this.wsReconnectTimer = setTimeout(async () => {
        this.wsReconnectTimer = null;
        this.startRealtime();
        // Backfill in case we missed messages while disconnected
        try {
          await this.loadMessages();
        } catch {
          // ignore
        }
      }, delayMs);
    },
    stopRealtime() {
      if (this.wsReconnectTimer) {
        clearTimeout(this.wsReconnectTimer);
        this.wsReconnectTimer = null;
      }
      this.wsReconnectAttempts = 0;
      if (this.ws) {
        try {
          this.ws.close();
        } catch {
          // ignore
        }
        this.ws = null;
      }
    },
    async sendMessage() {
      if (!this.newMessage.trim() || !this.threadId || !this.senderId || this.sending) return;

      this.sending = true;
      this.inlineError = null;
      const messageBody = this.newMessage.trim();
      this.newMessage = '';

      try {
        await messagingSendMessage(this.threadId, {
          senderType: this.senderType,
          senderId: this.senderId,
          body: messageBody,
        });
        await this.loadMessages();
        // After sending, we want to be at the bottom.
        this.unseenCount = 0;
        this.isAtBottom = true;
        this.afterMessagesChanged({ forceScroll: true });
      } catch (err) {
        if (err?.status === 401) {
          this.handleAuthExpired();
          return;
        }
        this.inlineError = 'Failed to send message: ' + (err?.message || String(err));
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

.thread-id-debug {
  font-size: 0.75rem;
  color: #888;
  margin-left: 0.5rem;
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
  position: relative;
}

.messages-list {
  flex: 1;
  overflow-y: auto;
  padding: 1rem;
}

.bottom-anchor {
  height: 1px;
}

.new-messages-button {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  bottom: 120px; /* above input */
  padding: 0.5rem 0.9rem;
  background: #111827;
  color: white;
  border: none;
  border-radius: 999px;
  cursor: pointer;
  font-size: 0.85rem;
  opacity: 0.92;
  z-index: 20;
}

.new-messages-button:hover {
  opacity: 1;
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

