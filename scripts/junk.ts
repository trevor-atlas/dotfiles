type None = null | undefined;
type Nullable<T> = T | None;

export type Expand<T> = T extends infer O ? { [K in keyof O]: O[K] } : never;

export type DeepPartial<T> = {
  [K in keyof T]?: T[K] extends object ? DeepPartial<T[K]> : T[K];
};

/** Make all of T's properties nullable */
export type NullableOfType<T> = {
  [P in keyof T]: Nullable<T[P]>;
};

/** ValueOf<{something: true, other: 1}> -> true | 1 */
export type ValueOf<T> = T[keyof T];

/** Correct type for Object.entries(myobj) */
export type Entries<T> = {
  [K in keyof T]: [K, T[K]];
}[keyof T][];

export function isNone<T>(nullable: Nullable<T>): nullable is None {
  return nullable === null || nullable === undefined;
}

export function isSome<T>(nullable: Nullable<T>): nullable is T {
  return !isNone(nullable);
}

export function isNumeric(value: Nullable<number>): value is number {
  return isSome(value) && !isNaN(value) && typeof value === 'number';
}

export function isError(error: Nullable<unknown>): error is Error {
  return error instanceof Error;
}

export function isString(x: Nullable<unknown>): x is string {
  return typeof x === 'string';
}

export function isObject(x: unknown): x is object {
  return isSome(x) && typeof x === 'object';
}

export const keysOf = Object.keys as <T extends object>(
  obj: T
) => Array<keyof T>;

export const valuesOf = Object.values as <T extends object>(
  obj: T
) => Array<ValueOf<T>>;

export const entriesOf = Object.entries as <T extends object>(
  obj: T
) => Entries<T>;

export const cloneOf = <T>(obj: T): T =>
  (structuredClone
    ? structuredClone(obj)
    : JSON.parse(JSON.stringify(obj))) as T;

export const mapEntries = <T extends object, V>(
  object: T,
  mapper: ([key, value]: [string, T[keyof T]]) => [string, V]
): { [key: string]: V } =>
  Object.fromEntries(Object.entries(object).map(([k, v]) => mapper([k, v])));

export const mapKeys = <T extends object>(
  object: T,
  mapper: (key: string, value: T[keyof T]) => string
): { [key: string]: T[keyof T] } =>
  Object.fromEntries(Object.entries(object).map(([k, v]) => [mapper(k, v), v]));

export const mapValues = <T extends object, V>(
  object: T,
  mapper: (value: T[keyof T], key: string) => V
): { [key: string]: V } =>
  Object.fromEntries(Object.entries(object).map(([k, v]) => [k, mapper(v, k)]));

export function callIfExists<Args extends any[], Fn extends (...args: Args) => any>(
  fn: Nullable<Fn>,
  ...fnArgs: Args
): ReturnType<Fn> | None {
    return (fn && fn(...fnArgs)) ?? null;
}

export function parseNumber(value: Nullable<string>): Nullable<number> {
  if (isNone(value) || value.trim() === '') {
    return null;
  }

  const parsed = Number(value);
  if (isNumeric(parsed)) {
    return parsed;
  }
  return null;
}
