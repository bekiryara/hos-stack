<template>
  <div id="app">
    <header>
      <h1>Marketplace</h1>
      <nav>
        <router-link to="/">Categories</router-link>
        <router-link to="/listing/create">Create Listing</router-link>
        <router-link to="/reservation/create">Create Reservation</router-link>
        <router-link to="/rental/create">Create Rental</router-link>
        <router-link to="/account">Account</router-link>
      </nav>
    </header>
    <main>
      <router-view />
    </main>
  </div>
</template>

<script>
export default {
  name: 'App',
};
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: system-ui, -apple-system, sans-serif;
  line-height: 1.6;
  color: #333;
}

#app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

header {
  background: #f5f5f5;
  padding: 1rem 2rem;
  border-bottom: 1px solid #ddd;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

header h1 {
  font-size: 1.5rem;
}

nav a {
  color: #0066cc;
  text-decoration: none;
  margin-left: 1rem;
}

nav a:hover {
  text-decoration: underline;
}

main {
  flex: 1;
  padding: 2rem;
  max-width: 1200px;
  width: 100%;
  margin: 0 auto;
}

.error {
  color: #d32f2f;
  padding: 1rem;
  background: #ffebee;
  border-radius: 4px;
  margin: 1rem 0;
}

.loading {
  text-align: center;
  padding: 2rem;
  color: #666;
}
</style>

