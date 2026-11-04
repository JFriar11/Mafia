import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';
export const games = sqliteTable('games', { code: text('code').primaryKey(), state: text('state').notNull(), revision: integer('revision').notNull().default(0), updated: integer('updated').notNull() });
