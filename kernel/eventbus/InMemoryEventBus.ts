import { EventBus, Event, EventName, EventHandler } from './EventBus';

export class InMemoryEventBus implements EventBus {
  private handlers: Map<EventName, EventHandler[]> = new Map();

  subscribe(name: EventName, handler: EventHandler) {
    const list = this.handlers.get(name) ?? [];
    list.push(handler);
    this.handlers.set(name, list);
  }

  async publish(event: Event) {
    const list = this.handlers.get(event.name) ?? [];
    for (const h of list) {
      await h(event);
    }
  }
}
