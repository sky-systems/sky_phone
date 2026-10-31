<template>
  <ul class="sky-admin-records">
    <slot />
  </ul>
</template>

<style>
.sky-admin-records {
  display: grid;
  gap: 2px;
  margin: 0;
  padding: 0;
  list-style: none;
  color: var(--admin-text, var(--sky-text));
}
.sky-admin-records > li {
  min-width: 0;
  border-radius: 3px;
  background: var(--admin-panel-raised, var(--sky-surface-muted));
}
.sky-admin-records > li:hover {
  background: var(--admin-row-hover, var(--sky-surface-variant));
}
.sky-admin-records__summary {
  display: grid;
  grid-template-columns: 30px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  min-height: var(--sky-touch-target);
  padding: 9px 12px;
  cursor: pointer;
  list-style: none;
}
.sky-admin-records__summary::-webkit-details-marker {
  display: none;
}
.sky-admin-records__summary:focus-visible {
  outline: 2px solid var(--sky-app-accent);
  outline-offset: -2px;
}
.sky-admin-records__icon {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  border-radius: 5px;
  color: var(--admin-accent, var(--sky-app-accent));
  background: var(--admin-green-soft, var(--sky-surface-variant));
}
.sky-admin-records__copy {
  display: grid;
  gap: 3px;
  min-width: 0;
}
.sky-admin-records__title {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  min-width: 0;
  font-size: 13px;
  font-weight: 550;
}
.sky-admin-records__title > strong {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: inherit;
}
.sky-admin-records__meta,
.sky-admin-records__title time {
  color: var(--admin-muted, var(--sky-field-placeholder));
  font-size: 11px;
  font-weight: 400;
}
.sky-admin-records__title time {
  flex: none;
  white-space: nowrap;
}
.sky-admin-records__preview {
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
  margin: 0;
  color: var(--admin-muted, var(--sky-text));
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.sky-admin-records__chevron {
  color: var(--admin-muted, var(--sky-text));
  transition: transform var(--sky-transition-fast);
}
details[open] > summary .sky-admin-records__chevron {
  transform: rotate(180deg);
}
.sky-admin-records__details {
  display: grid;
  gap: 10px;
  padding: 0 12px 12px 52px;
  min-width: 0;
  font-size: 12px;
  overflow-wrap: anywhere;
}
.sky-admin-records__details p {
  margin: 0;
  white-space: pre-wrap;
}
.sky-admin-records__details dl {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 6px 12px;
  margin: 0;
}
.sky-admin-records__details dt {
  color: var(--admin-muted, var(--sky-text));
}
.sky-admin-records__details dd {
  margin: 0;
}
.sky-admin-records__details pre {
  margin: 0;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  font-size: 11px;
}
@media (max-width: 700px) {
  .sky-admin-records__title {
    align-items: start;
    flex-direction: column;
    gap: 3px;
  }
}
@media (prefers-reduced-motion: reduce) {
  .sky-admin-records__chevron {
    transition: none;
  }
}
</style>
