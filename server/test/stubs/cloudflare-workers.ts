// Node stand-in for the workerd-only "cloudflare:workers" module (see vitest.config.ts).
export class DurableObject {
  constructor(public ctx: any, public env: any) {}
}
