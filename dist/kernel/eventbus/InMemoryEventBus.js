"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InMemoryEventBus = void 0;
class InMemoryEventBus {
    constructor() {
        this.handlers = new Map();
    }
    subscribe(name, handler) {
        const list = this.handlers.get(name) ?? [];
        list.push(handler);
        this.handlers.set(name, list);
    }
    async publish(event) {
        const list = this.handlers.get(event.name) ?? [];
        for (const h of list) {
            await h(event);
        }
    }
}
exports.InMemoryEventBus = InMemoryEventBus;
