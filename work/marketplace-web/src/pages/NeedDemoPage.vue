<template>
  <div class="need-demo-page" data-marker="need-demo">
    <div class="content">
      <h2>Demo Session Required</h2>
      <p>You need to enter the demo session to access this page.</p>
      <button @click="enterDemo" class="enter-demo-button" data-marker="enter-demo">
        Enter Demo
      </button>
    </div>
  </div>
</template>

<script>
import { enterDemoUrl } from '../lib/demoSession.js';

export default {
  name: 'NeedDemoPage',
  methods: {
    enterDemo() {
      window.location.href = enterDemoUrl;
    },
  },
};
</script>

<style scoped>
.need-demo-page {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 60vh;
  padding: 2rem;
}

.content {
  text-align: center;
  max-width: 500px;
}

.content h2 {
  margin-bottom: 1rem;
  font-size: 1.8rem;
}

.content p {
  margin-bottom: 2rem;
  color: #666;
  font-size: 1.1rem;
}

.enter-demo-button {
  padding: 0.75rem 2rem;
  border: none;
  border-radius: 4px;
  background: #0066cc;
  color: white;
  cursor: pointer;
  font-size: 1rem;
  font-weight: bold;
}

.enter-demo-button:hover {
  background: #0052a3;
}
</style>

