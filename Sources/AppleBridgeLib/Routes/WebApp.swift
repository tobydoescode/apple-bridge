let webAppHTML = ##"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Reminders</title>
<style>
:root {
  --bg-primary: #ffffff;
  --bg-secondary: #f5f5f7;
  --bg-hover: #e8e8ed;
  --bg-selected: #e3e3e8;
  --text-primary: #1d1d1f;
  --text-secondary: #86868b;
  --text-tertiary: #aeaeb2;
  --border: #d2d2d7;
  --accent: #007aff;
  --accent-hover: #0066d6;
  --danger: #ff3b30;
  --priority-high: #ff3b30;
  --priority-medium: #ff9500;
  --priority-low: #007aff;
  --radius: 8px;
  --radius-lg: 12px;
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body {
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
  color: var(--text-primary);
  background: var(--bg-secondary);
  height: 100vh;
  overflow: hidden;
}

/* LOGIN */
#login-screen {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100vh;
  background: var(--bg-secondary);
}

.login-card {
  background: var(--bg-primary);
  border-radius: var(--radius-lg);
  padding: 40px;
  width: 380px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.1);
  text-align: center;
}

.login-card h1 {
  font-size: 24px;
  font-weight: 600;
  margin-bottom: 8px;
}

.login-card p {
  color: var(--text-secondary);
  font-size: 14px;
  margin-bottom: 24px;
}

.login-card input {
  width: 100%;
  padding: 10px 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  font-size: 14px;
  outline: none;
  margin-bottom: 16px;
}

.login-card input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(0,122,255,0.15);
}

.login-card button {
  width: 100%;
  padding: 10px;
  background: var(--accent);
  color: white;
  border: none;
  border-radius: var(--radius);
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
}

.login-card button:hover { background: var(--accent-hover); }

.login-error {
  color: var(--danger);
  font-size: 13px;
  margin-top: 12px;
  display: none;
}

/* APP SHELL */
#app-shell {
  display: none;
  grid-template-columns: 260px 1fr;
  height: 100vh;
}

#app-shell.with-detail {
  grid-template-columns: 260px 1fr 360px;
}

/* SIDEBAR */
#sidebar {
  background: var(--bg-secondary);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.sidebar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 16px 8px;
}

.sidebar-header h2 {
  font-size: 20px;
  font-weight: 700;
}

.sidebar-header button {
  background: none;
  border: none;
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 18px;
  padding: 4px;
  border-radius: 4px;
}

.sidebar-header button:hover { background: var(--bg-hover); }

.search-box {
  padding: 4px 16px 12px;
}

.search-box input {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  font-size: 13px;
  background: var(--bg-primary);
  outline: none;
}

.search-box input:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(0,122,255,0.15);
}

.lists-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 16px 4px;
}

.lists-header span {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--text-secondary);
  letter-spacing: 0.5px;
}

.lists-header button {
  background: none;
  border: none;
  color: var(--accent);
  cursor: pointer;
  font-size: 18px;
  font-weight: 300;
  padding: 0 4px;
  border-radius: 4px;
}

.lists-header button:hover { background: var(--bg-hover); }

#list-items {
  flex: 1;
  overflow-y: auto;
  padding: 4px 8px;
}

.list-item {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border-radius: var(--radius);
  cursor: pointer;
  gap: 10px;
  user-select: none;
}

.list-item:hover { background: var(--bg-hover); }
.list-item.selected { background: var(--bg-selected); }

.list-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  flex-shrink: 0;
}

.list-title {
  flex: 1;
  font-size: 14px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.list-count {
  font-size: 13px;
  color: var(--text-secondary);
  flex-shrink: 0;
}

/* CONTENT */
#content {
  background: var(--bg-primary);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.content-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px 12px;
  border-bottom: 1px solid var(--border);
}

.content-header h2 {
  font-size: 22px;
  font-weight: 700;
}

.content-header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.toggle-completed {
  font-size: 13px;
  color: var(--accent);
  cursor: pointer;
  background: none;
  border: none;
}

.toggle-completed:hover { text-decoration: underline; }

#reminder-items {
  flex: 1;
  overflow-y: auto;
  padding: 8px 0;
}

.reminder-row {
  display: flex;
  align-items: flex-start;
  padding: 10px 20px;
  cursor: pointer;
  gap: 12px;
  border-bottom: 1px solid #f0f0f0;
}

.reminder-row:hover { background: #fafafa; }
.reminder-row.selected { background: #f0f4ff; }

.reminder-checkbox {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 2px solid var(--border);
  flex-shrink: 0;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 1px;
  transition: all 0.15s;
}

.reminder-checkbox:hover {
  border-color: var(--accent);
}

.reminder-checkbox.checked {
  background: var(--accent);
  border-color: var(--accent);
}

.reminder-checkbox.checked::after {
  content: '\2713';
  color: white;
  font-size: 13px;
  font-weight: 700;
}

.reminder-content {
  flex: 1;
  min-width: 0;
}

.reminder-title {
  font-size: 14px;
  line-height: 1.4;
}

.reminder-title.completed {
  text-decoration: line-through;
  color: var(--text-secondary);
}

.reminder-meta {
  display: flex;
  gap: 8px;
  align-items: center;
  margin-top: 2px;
  flex-wrap: wrap;
}

.reminder-notes-preview {
  font-size: 12px;
  color: var(--text-secondary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 200px;
}

.reminder-due {
  font-size: 12px;
  color: var(--text-secondary);
}

.reminder-due.overdue { color: var(--danger); }
.reminder-due.today { color: var(--accent); }

.reminder-priority {
  font-size: 12px;
  font-weight: 700;
}

.priority-high { color: var(--priority-high); }
.priority-medium { color: var(--priority-medium); }
.priority-low { color: var(--priority-low); }

.reminder-delete {
  opacity: 0;
  background: none;
  border: none;
  color: var(--text-tertiary);
  cursor: pointer;
  font-size: 16px;
  padding: 4px;
  flex-shrink: 0;
}

.reminder-row:hover .reminder-delete { opacity: 1; }
.reminder-delete:hover { color: var(--danger); }

/* NEW REMINDER */
.new-reminder {
  padding: 10px 20px;
  border-bottom: 1px solid #f0f0f0;
}

.new-reminder-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--accent);
  font-size: 14px;
  cursor: pointer;
  padding: 6px 0;
  background: none;
  border: none;
  width: 100%;
  text-align: left;
}

.new-reminder-btn:hover { opacity: 0.8; }

.new-reminder-input {
  width: 100%;
  padding: 8px 0;
  border: none;
  font-size: 14px;
  outline: none;
  display: none;
}

/* DETAIL PANEL */
#detail-panel {
  background: var(--bg-primary);
  border-left: 1px solid var(--border);
  display: none;
  flex-direction: column;
  overflow-y: auto;
}

#detail-panel.visible {
  display: flex;
}

.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px 12px;
  border-bottom: 1px solid var(--border);
}

.detail-header h3 {
  font-size: 16px;
  font-weight: 600;
}

.detail-close {
  background: none;
  border: none;
  font-size: 20px;
  color: var(--text-secondary);
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
}

.detail-close:hover { background: var(--bg-hover); }

.detail-body {
  padding: 16px 20px;
  flex: 1;
}

.field-group {
  margin-bottom: 16px;
}

.field-group label {
  display: block;
  font-size: 12px;
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: 4px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.field-group input,
.field-group textarea,
.field-group select {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid var(--border);
  border-radius: 6px;
  font-size: 14px;
  font-family: inherit;
  outline: none;
}

.field-group input:focus,
.field-group textarea:focus,
.field-group select:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(0,122,255,0.15);
}

.field-group textarea {
  resize: vertical;
  min-height: 60px;
}

.priority-selector {
  display: flex;
  gap: 0;
  border: 1px solid var(--border);
  border-radius: 6px;
  overflow: hidden;
}

.priority-option {
  flex: 1;
  padding: 7px 4px;
  text-align: center;
  font-size: 13px;
  cursor: pointer;
  background: var(--bg-primary);
  border: none;
  border-right: 1px solid var(--border);
  transition: all 0.15s;
}

.priority-option:last-child { border-right: none; }
.priority-option:hover { background: var(--bg-hover); }
.priority-option.selected {
  background: var(--accent);
  color: white;
}

.detail-footer {
  padding: 16px 20px;
  border-top: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.btn-delete {
  background: none;
  border: none;
  color: var(--danger);
  font-size: 13px;
  cursor: pointer;
}

.btn-delete:hover { text-decoration: underline; }

.detail-footer-right {
  display: flex;
  gap: 8px;
}

.btn-cancel {
  padding: 7px 16px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--bg-primary);
  font-size: 13px;
  cursor: pointer;
}

.btn-cancel:hover { background: var(--bg-hover); }

.btn-save {
  padding: 7px 16px;
  border: none;
  border-radius: 6px;
  background: var(--accent);
  color: white;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
}

.btn-save:hover { background: var(--accent-hover); }

/* LIST MODAL */
.modal-overlay {
  display: none;
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.3);
  z-index: 100;
  align-items: center;
  justify-content: center;
}

.modal-overlay.visible { display: flex; }

.modal {
  background: var(--bg-primary);
  border-radius: var(--radius-lg);
  padding: 24px;
  width: 360px;
  box-shadow: 0 8px 40px rgba(0,0,0,0.15);
}

.modal h3 {
  font-size: 17px;
  font-weight: 600;
  margin-bottom: 16px;
}

.color-swatches {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-top: 4px;
}

.color-swatch {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  cursor: pointer;
  border: 3px solid transparent;
  transition: border-color 0.15s;
}

.color-swatch:hover { opacity: 0.8; }
.color-swatch.selected { border-color: var(--text-primary); }

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 20px;
}

/* CONTEXT MENU */
.context-menu {
  display: none;
  position: fixed;
  background: var(--bg-primary);
  border-radius: var(--radius);
  box-shadow: 0 4px 20px rgba(0,0,0,0.15);
  padding: 4px 0;
  z-index: 200;
  min-width: 160px;
}

.context-menu.visible { display: block; }

.context-menu-item {
  padding: 8px 16px;
  font-size: 13px;
  cursor: pointer;
}

.context-menu-item:hover { background: var(--bg-hover); }
.context-menu-item.danger { color: var(--danger); }

/* TOAST */
#toast {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%) translateY(80px);
  background: var(--text-primary);
  color: white;
  padding: 10px 20px;
  border-radius: var(--radius);
  font-size: 14px;
  z-index: 300;
  transition: transform 0.3s ease;
  pointer-events: none;
}

#toast.visible {
  transform: translateX(-50%) translateY(0);
}

/* EMPTY STATE */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-tertiary);
}

.empty-state span {
  font-size: 48px;
  margin-bottom: 12px;
}

.empty-state p {
  font-size: 15px;
}
</style>
</head>
<body>

<div id="login-screen">
  <div class="login-card">
    <h1>Reminders</h1>
    <p>Enter your API token to connect</p>
    <input type="password" id="token-input" placeholder="API Token" autocomplete="off">
    <button id="login-btn">Connect</button>
    <div class="login-error" id="login-error">Invalid API token</div>
  </div>
</div>

<div id="app-shell">
  <div id="sidebar">
    <div class="sidebar-header">
      <h2>Reminders</h2>
      <button id="logout-btn" title="Logout">&#9881;</button>
    </div>
    <div class="search-box">
      <input type="text" id="search-input" placeholder="Search">
    </div>
    <div class="lists-header">
      <span>My Lists</span>
      <button id="add-list-btn" title="New List" class="write-only">+</button>
    </div>
    <div id="list-items"></div>
  </div>
  <div id="content">
    <div class="content-header">
      <h2 id="content-title">Reminders</h2>
      <div class="content-header-actions">
        <button class="toggle-completed" id="toggle-completed">Show Completed</button>
      </div>
    </div>
    <div class="new-reminder write-only">
      <button class="new-reminder-btn" id="new-reminder-btn">+ New Reminder</button>
      <input type="text" class="new-reminder-input" id="new-reminder-input" placeholder="Title">
    </div>
    <div id="reminder-items"></div>
  </div>
  <div id="detail-panel">
    <div class="detail-header">
      <h3>Edit Reminder</h3>
      <button class="detail-close" id="detail-close">&times;</button>
    </div>
    <div class="detail-body">
      <div class="field-group">
        <label>Title</label>
        <input type="text" id="detail-title">
      </div>
      <div class="field-group">
        <label>Notes</label>
        <textarea id="detail-notes"></textarea>
      </div>
      <div class="field-group">
        <label>Due Date</label>
        <input type="datetime-local" id="detail-due">
      </div>
      <div class="field-group">
        <label>Priority</label>
        <div class="priority-selector" id="priority-selector">
          <button class="priority-option" data-value="0">None</button>
          <button class="priority-option" data-value="9">Low</button>
          <button class="priority-option" data-value="5">Medium</button>
          <button class="priority-option" data-value="1">High</button>
        </div>
      </div>
      <div class="field-group">
        <label>URL</label>
        <input type="url" id="detail-url" placeholder="https://">
      </div>
      <div class="field-group">
        <label>List</label>
        <select id="detail-list"></select>
      </div>
    </div>
    <div class="detail-footer">
      <button class="btn-delete" id="detail-delete">Delete Reminder</button>
      <div class="detail-footer-right">
        <button class="btn-cancel" id="detail-cancel">Cancel</button>
        <button class="btn-save" id="detail-save">Save</button>
      </div>
    </div>
  </div>
</div>

<div class="modal-overlay" id="list-modal">
  <div class="modal">
    <h3 id="list-modal-title">New List</h3>
    <div class="field-group">
      <label>Title</label>
      <input type="text" id="list-modal-name" placeholder="List name">
    </div>
    <div class="field-group">
      <label>Color</label>
      <div class="color-swatches" id="color-swatches"></div>
    </div>
    <div class="modal-footer">
      <button class="btn-cancel" id="list-modal-cancel">Cancel</button>
      <button class="btn-save" id="list-modal-save">Save</button>
    </div>
  </div>
</div>

<div class="context-menu" id="context-menu">
  <div class="context-menu-item" id="ctx-edit">Edit List</div>
  <div class="context-menu-item danger" id="ctx-delete">Delete List</div>
</div>

<div id="toast"></div>

<script>
const COLORS = [
  '#007aff','#34c759','#ff9500','#ff3b30','#af52de',
  '#ff2d55','#5856d6','#00c7be','#a2845e','#8e8e93'
];

const API = {
  token: null,
  async request(method, path, body) {
    const opts = {
      method,
      headers: { 'Authorization': 'Bearer ' + this.token }
    };
    if (body) {
      opts.headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(path, opts);
    if (res.status === 401) {
      localStorage.removeItem('apiToken');
      this.token = null;
      App.showLogin();
      throw new Error('Unauthorized');
    }
    if (res.status === 204) return null;
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || 'Request failed');
    }
    return res.json();
  },
  getLists() { return this.request('GET', '/reminder-lists'); },
  createList(d) { return this.request('POST', '/reminder-lists', d); },
  updateList(id, d) { return this.request('PUT', '/reminder-lists/' + id, d); },
  deleteList(id) { return this.request('DELETE', '/reminder-lists/' + id); },
  getReminders(params) {
    const q = new URLSearchParams();
    if (params) Object.entries(params).forEach(([k,v]) => { if (v != null) q.set(k, v); });
    const qs = q.toString();
    return this.request('GET', '/reminders' + (qs ? '?' + qs : ''));
  },
  createReminder(d) { return this.request('POST', '/reminders', d); },
  updateReminder(id, d) { return this.request('PATCH', '/reminders/' + id, d); },
  deleteReminder(id) { return this.request('DELETE', '/reminders/' + id); },
  completeReminder(id) { return this.request('POST', '/reminders/' + id + '/complete'); },
  uncompleteReminder(id) { return this.request('POST', '/reminders/' + id + '/uncomplete'); },
  getMe() { return this.request('GET', '/auth/me'); },
};

const Store = {
  lists: [],
  reminders: [],
  allIncomplete: [],
  selectedListId: null,
  selectedReminderId: null,
  showCompleted: false,
  searchQuery: '',
  readOnly: false,

  async loadLists() {
    const data = await API.getLists();
    this.lists = data.items;
  },

  async loadCounts() {
    const data = await API.getReminders({ completed: false });
    this.allIncomplete = data.items;
  },

  getCount(listId) {
    return this.allIncomplete.filter(r => r.listId === listId).length;
  },

  async loadReminders() {
    const params = {};
    if (this.selectedListId) params.listId = this.selectedListId;
    params.completed = this.showCompleted ? 'all' : 'false';
    const data = await API.getReminders(params);
    this.reminders = data.items;
  },

  getFilteredReminders() {
    if (!this.searchQuery) return this.reminders;
    const q = this.searchQuery.toLowerCase();
    return this.reminders.filter(r =>
      (r.title && r.title.toLowerCase().includes(q)) ||
      (r.notes && r.notes.toLowerCase().includes(q))
    );
  },

  getSelectedReminder() {
    return this.reminders.find(r => r.id === this.selectedReminderId);
  }
};

function formatDue(dateStr) {
  if (!dateStr) return null;
  const d = new Date(dateStr);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const tomorrow = new Date(today); tomorrow.setDate(today.getDate() + 1);
  const dayAfter = new Date(today); dayAfter.setDate(today.getDate() + 2);

  if (d >= today && d < tomorrow) return { text: 'Today', cls: 'today' };
  if (d >= tomorrow && d < dayAfter) return { text: 'Tomorrow', cls: '' };
  if (d < today) return { text: 'Overdue', cls: 'overdue' };
  const opts = { month: 'short', day: 'numeric' };
  if (d.getFullYear() !== now.getFullYear()) opts.year = 'numeric';
  return { text: d.toLocaleDateString(undefined, opts), cls: '' };
}

function priorityDisplay(p) {
  if (p === 1) return '<span class="reminder-priority priority-high">!!!</span>';
  if (p === 5) return '<span class="reminder-priority priority-medium">!!</span>';
  if (p === 9) return '<span class="reminder-priority priority-low">!</span>';
  return '';
}

function toLocalDatetime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = n => String(n).padStart(2, '0');
  return d.getFullYear() + '-' + pad(d.getMonth()+1) + '-' + pad(d.getDate()) +
    'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

function escapeHTML(s) {
  if (!s) return '';
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

let debounceTimer;
function debounce(fn, ms) {
  return function(...args) {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => fn(...args), ms);
  };
}

const UI = {
  renderSidebar() {
    const el = document.getElementById('list-items');
    el.innerHTML = Store.lists.map(l => {
      const sel = l.id === Store.selectedListId ? ' selected' : '';
      const color = l.color || '#007aff';
      const count = Store.getCount(l.id);
      return '<div class="list-item' + sel + '" data-id="' + l.id + '">' +
        '<div class="list-dot" style="background:' + escapeHTML(color) + '"></div>' +
        '<div class="list-title">' + escapeHTML(l.title) + '</div>' +
        (count > 0 ? '<div class="list-count">' + count + '</div>' : '') +
        '</div>';
    }).join('');
  },

  renderReminderList() {
    const el = document.getElementById('reminder-items');
    const list = Store.lists.find(l => l.id === Store.selectedListId);
    const title = document.getElementById('content-title');
    const toggleBtn = document.getElementById('toggle-completed');

    if (list) {
      title.textContent = list.title;
      title.style.color = list.color || '#007aff';
    } else {
      title.textContent = Store.searchQuery ? 'Search Results' : 'Reminders';
      title.style.color = '';
    }
    toggleBtn.textContent = Store.showCompleted ? 'Hide Completed' : 'Show Completed';

    const reminders = Store.getFilteredReminders();
    if (reminders.length === 0) {
      el.innerHTML = '<div class="empty-state"><span>&#10003;</span><p>No Reminders</p></div>';
      return;
    }

    el.innerHTML = reminders.map(r => {
      const sel = r.id === Store.selectedReminderId ? ' selected' : '';
      const checked = r.isCompleted ? ' checked' : '';
      const completedCls = r.isCompleted ? ' completed' : '';
      const due = formatDue(r.dueDate);
      let meta = '';
      if (due) meta += '<span class="reminder-due ' + due.cls + '">' + due.text + '</span>';
      meta += priorityDisplay(r.priority);
      if (r.notes) meta += '<span class="reminder-notes-preview">' + escapeHTML(r.notes) + '</span>';

      const checkbox = Store.readOnly
        ? '<div class="reminder-checkbox' + checked + '"></div>'
        : '<div class="reminder-checkbox' + checked + '" data-action="toggle" data-id="' + r.id + '"></div>';
      const deleteBtn = Store.readOnly
        ? ''
        : '<button class="reminder-delete" data-action="delete" data-id="' + r.id + '" title="Delete">&times;</button>';

      return '<div class="reminder-row' + sel + '" data-id="' + r.id + '">' +
        checkbox +
        '<div class="reminder-content">' +
        '<div class="reminder-title' + completedCls + '">' + escapeHTML(r.title) + '</div>' +
        (meta ? '<div class="reminder-meta">' + meta + '</div>' : '') +
        '</div>' +
        deleteBtn +
        '</div>';
    }).join('');
  },

  showDetailPanel(reminder) {
    if (!reminder) { this.hideDetailPanel(); return; }
    Store.selectedReminderId = reminder.id;
    document.getElementById('app-shell').classList.add('with-detail');
    document.getElementById('detail-panel').classList.add('visible');

    document.getElementById('detail-title').value = reminder.title || '';
    document.getElementById('detail-notes').value = reminder.notes || '';
    document.getElementById('detail-due').value = toLocalDatetime(reminder.dueDate);
    document.getElementById('detail-url').value = reminder.url || '';

    const listSelect = document.getElementById('detail-list');
    listSelect.innerHTML = Store.lists.map(l =>
      '<option value="' + l.id + '"' + (l.id === reminder.listId ? ' selected' : '') + '>' +
      escapeHTML(l.title) + '</option>'
    ).join('');

    document.querySelectorAll('.priority-option').forEach(btn => {
      btn.classList.toggle('selected', parseInt(btn.dataset.value) === (reminder.priority || 0));
    });

    this.renderReminderList();
  },

  hideDetailPanel() {
    Store.selectedReminderId = null;
    document.getElementById('app-shell').classList.remove('with-detail');
    document.getElementById('detail-panel').classList.remove('visible');
    this.renderReminderList();
  },

  showListModal(list) {
    document.getElementById('list-modal').classList.add('visible');
    document.getElementById('list-modal-title').textContent = list ? 'Edit List' : 'New List';
    document.getElementById('list-modal-name').value = list ? list.title : '';
    document.getElementById('list-modal').dataset.editId = list ? list.id : '';

    const swatches = document.getElementById('color-swatches');
    const currentColor = list ? (list.color || '#007aff') : '#007aff';
    swatches.innerHTML = COLORS.map(c => {
      const sel = c.toLowerCase() === currentColor.toLowerCase() ? ' selected' : '';
      return '<div class="color-swatch' + sel + '" data-color="' + c + '" style="background:' + c + '"></div>';
    }).join('');

    document.getElementById('list-modal-name').focus();
  },

  hideListModal() {
    document.getElementById('list-modal').classList.remove('visible');
  },

  showToast(msg, isError) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.style.background = isError ? 'var(--danger)' : 'var(--text-primary)';
    el.classList.add('visible');
    setTimeout(() => el.classList.remove('visible'), 3000);
  }
};

const App = {
  init() {
    API.token = localStorage.getItem('apiToken');
    if (API.token) {
      this.loadApp();
    } else {
      this.showLogin();
    }
    this.bindEvents();
  },

  showLogin() {
    document.getElementById('login-screen').style.display = 'flex';
    document.getElementById('app-shell').style.display = 'none';
    document.getElementById('token-input').focus();
  },

  async loadApp() {
    document.getElementById('login-screen').style.display = 'none';
    document.getElementById('app-shell').style.display = 'grid';

    try {
      const me = await API.getMe();
      Store.readOnly = me.permission === 'read';
      this.applyReadOnly();

      await Store.loadLists();
      await Store.loadCounts();
      UI.renderSidebar();

      if (Store.lists.length > 0) {
        const def = Store.lists.find(l => l.isDefault) || Store.lists[0];
        await this.selectList(def.id);
      }
    } catch(e) {
      UI.showToast('Failed to load: ' + e.message, true);
    }
  },

  async selectList(id) {
    Store.selectedListId = id;
    Store.selectedReminderId = null;
    UI.hideDetailPanel();
    UI.renderSidebar();
    await Store.loadReminders();
    UI.renderReminderList();
  },

  applyReadOnly() {
    const els = document.querySelectorAll('.write-only');
    els.forEach(el => el.style.display = Store.readOnly ? 'none' : '');
  },

  async refreshAll() {
    await Store.loadCounts();
    await Store.loadReminders();
    UI.renderSidebar();
    UI.renderReminderList();
  },

  bindEvents() {
    // Login
    document.getElementById('login-btn').addEventListener('click', async () => {
      const token = document.getElementById('token-input').value.trim();
      if (!token) return;
      API.token = token;
      try {
        await API.getLists();
        localStorage.setItem('apiToken', token);
        this.loadApp();
      } catch(e) {
        document.getElementById('login-error').style.display = 'block';
        API.token = null;
      }
    });

    document.getElementById('token-input').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') document.getElementById('login-btn').click();
    });

    // Logout
    document.getElementById('logout-btn').addEventListener('click', () => {
      localStorage.removeItem('apiToken');
      API.token = null;
      this.showLogin();
    });

    // List selection
    document.getElementById('list-items').addEventListener('click', (e) => {
      const item = e.target.closest('.list-item');
      if (item) this.selectList(item.dataset.id);
    });

    // List context menu
    document.getElementById('list-items').addEventListener('contextmenu', (e) => {
      if (Store.readOnly) return;
      const item = e.target.closest('.list-item');
      if (!item) return;
      e.preventDefault();
      const menu = document.getElementById('context-menu');
      menu.style.top = e.clientY + 'px';
      menu.style.left = e.clientX + 'px';
      menu.classList.add('visible');
      menu.dataset.listId = item.dataset.id;
    });

    document.addEventListener('click', () => {
      document.getElementById('context-menu').classList.remove('visible');
    });

    document.getElementById('ctx-edit').addEventListener('click', () => {
      const id = document.getElementById('context-menu').dataset.listId;
      const list = Store.lists.find(l => l.id === id);
      if (list) UI.showListModal(list);
    });

    document.getElementById('ctx-delete').addEventListener('click', async () => {
      const id = document.getElementById('context-menu').dataset.listId;
      const list = Store.lists.find(l => l.id === id);
      if (!list || !confirm('Delete "' + list.title + '"? All reminders in this list will be deleted.')) return;
      try {
        await API.deleteList(id);
        await Store.loadLists();
        await Store.loadCounts();
        UI.renderSidebar();
        if (Store.selectedListId === id && Store.lists.length > 0) {
          this.selectList(Store.lists[0].id);
        } else if (Store.lists.length === 0) {
          Store.selectedListId = null;
          Store.reminders = [];
          UI.renderReminderList();
        }
        UI.showToast('List deleted');
      } catch(e) { UI.showToast(e.message, true); }
    });

    // Add list
    document.getElementById('add-list-btn').addEventListener('click', () => UI.showListModal(null));

    // List modal
    document.getElementById('color-swatches').addEventListener('click', (e) => {
      const swatch = e.target.closest('.color-swatch');
      if (!swatch) return;
      document.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
      swatch.classList.add('selected');
    });

    document.getElementById('list-modal-cancel').addEventListener('click', () => UI.hideListModal());

    document.getElementById('list-modal-save').addEventListener('click', async () => {
      const title = document.getElementById('list-modal-name').value.trim();
      if (!title) return;
      const selectedSwatch = document.querySelector('.color-swatch.selected');
      const color = selectedSwatch ? selectedSwatch.dataset.color : '#007aff';
      const editId = document.getElementById('list-modal').dataset.editId;

      try {
        if (editId) {
          await API.updateList(editId, { title, color });
        } else {
          await API.createList({ title, color });
        }
        await Store.loadLists();
        UI.renderSidebar();
        UI.hideListModal();
        UI.showToast(editId ? 'List updated' : 'List created');
      } catch(e) { UI.showToast(e.message, true); }
    });

    document.getElementById('list-modal').addEventListener('click', (e) => {
      if (e.target === document.getElementById('list-modal')) UI.hideListModal();
    });

    // Toggle completed
    document.getElementById('toggle-completed').addEventListener('click', async () => {
      Store.showCompleted = !Store.showCompleted;
      await Store.loadReminders();
      UI.renderReminderList();
    });

    // New reminder
    const newBtn = document.getElementById('new-reminder-btn');
    const newInput = document.getElementById('new-reminder-input');

    newBtn.addEventListener('click', () => {
      newBtn.style.display = 'none';
      newInput.style.display = 'block';
      newInput.focus();
    });

    newInput.addEventListener('keydown', async (e) => {
      if (e.key === 'Enter') {
        const title = newInput.value.trim();
        if (!title) return;
        try {
          await API.createReminder({ title, listId: Store.selectedListId });
          newInput.value = '';
          await this.refreshAll();
          UI.showToast('Reminder created');
        } catch(err) { UI.showToast(err.message, true); }
      }
      if (e.key === 'Escape') {
        newInput.value = '';
        newInput.style.display = 'none';
        newBtn.style.display = 'flex';
      }
    });

    newInput.addEventListener('blur', () => {
      if (!newInput.value.trim()) {
        newInput.style.display = 'none';
        newBtn.style.display = 'flex';
      }
    });

    // Reminder interactions
    document.getElementById('reminder-items').addEventListener('click', async (e) => {
      const action = e.target.dataset.action;
      const id = e.target.dataset.id;

      if (action === 'toggle' && id) {
        const r = Store.reminders.find(x => x.id === id);
        if (!r) return;
        try {
          if (r.isCompleted) {
            await API.uncompleteReminder(id);
          } else {
            await API.completeReminder(id);
          }
          await this.refreshAll();
        } catch(err) { UI.showToast(err.message, true); }
        return;
      }

      if (action === 'delete' && id) {
        if (!confirm('Delete this reminder?')) return;
        try {
          await API.deleteReminder(id);
          if (Store.selectedReminderId === id) UI.hideDetailPanel();
          await this.refreshAll();
          UI.showToast('Reminder deleted');
        } catch(err) { UI.showToast(err.message, true); }
        return;
      }

      const row = e.target.closest('.reminder-row');
      if (row && !action) {
        const r = Store.reminders.find(x => x.id === row.dataset.id);
        if (r && !Store.readOnly) UI.showDetailPanel(r);
      }
    });

    // Detail panel
    document.getElementById('detail-close').addEventListener('click', () => UI.hideDetailPanel());
    document.getElementById('detail-cancel').addEventListener('click', () => UI.hideDetailPanel());

    document.getElementById('priority-selector').addEventListener('click', (e) => {
      const opt = e.target.closest('.priority-option');
      if (!opt) return;
      document.querySelectorAll('.priority-option').forEach(b => b.classList.remove('selected'));
      opt.classList.add('selected');
    });

    document.getElementById('detail-save').addEventListener('click', async () => {
      const id = Store.selectedReminderId;
      if (!id) return;
      const selPriority = document.querySelector('.priority-option.selected');
      const dueVal = document.getElementById('detail-due').value;

      const data = {
        title: document.getElementById('detail-title').value,
        notes: document.getElementById('detail-notes').value || null,
        dueDate: dueVal ? new Date(dueVal).toISOString() : null,
        priority: selPriority ? parseInt(selPriority.dataset.value) : 0,
        url: document.getElementById('detail-url').value || null,
        listId: document.getElementById('detail-list').value,
      };

      try {
        await API.updateReminder(id, data);
        await this.refreshAll();
        const updated = Store.reminders.find(r => r.id === id);
        if (updated) UI.showDetailPanel(updated);
        UI.showToast('Reminder saved');
      } catch(err) { UI.showToast(err.message, true); }
    });

    document.getElementById('detail-delete').addEventListener('click', async () => {
      const id = Store.selectedReminderId;
      if (!id || !confirm('Delete this reminder?')) return;
      try {
        await API.deleteReminder(id);
        UI.hideDetailPanel();
        await this.refreshAll();
        UI.showToast('Reminder deleted');
      } catch(err) { UI.showToast(err.message, true); }
    });

    // Search
    document.getElementById('search-input').addEventListener('input', debounce(async (e) => {
      Store.searchQuery = e.target.value.trim();
      if (Store.searchQuery) {
        const data = await API.getReminders({ completed: 'all' });
        Store.reminders = data.items;
      } else {
        await Store.loadReminders();
      }
      UI.renderReminderList();
    }, 300));

    // Keyboard
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        UI.hideDetailPanel();
        UI.hideListModal();
      }
    });
  }
};

App.init();
</script>
</body>
</html>
"""##
