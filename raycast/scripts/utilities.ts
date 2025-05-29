interface Ok<T> {
  ok: true;
  value: T;
}
interface Err<E> {
  ok: false;
  error: E;
}

type Result<T, E = unknown> = (Ok<T> | Err<E>) & {
  map: <U>(fn: (value: T) => U) => Result<U, E>;
  orElse: <U>(fn: (error: E) => U) => Result<T, U>;
  unwrap: () => T | E;
  match: <U, V>(ok: (value: T) => U, err: (error: E) => V) => Result<U, V>;
};

export function toError(value: unknown): Error {
  if (value === null || value === undefined) {
    return value === null ? new Error('Null value') : new Error('Undefined value');
  }

  if (value instanceof Error) {
    return value;
  }

  // "", 0, NaN
  if (!value) {
    return new Error('Unknown error');
  }

  return new Error(String(value));
}

export function ok<T>(value: T): Result<T, never> {
  return {
    ok: true,
    value,
    map: (fn) => ok(fn(value)),
    orElse: () => ok(value),
    unwrap: () => value,
    match: (okCallback) => ok(okCallback(value)),
  };
}

export function err<E>(error: E): Result<never, E> {
  return {
    ok: false,
    error,
    map: () => err(error),
    orElse: (fn) => err(fn(error)),
    unwrap: () => error,
    match: (__, errCallback) => err(errCallback(error)),
  };
}

export async function tryCatchAsync<T, E = unknown>(
  callback: () => Promise<T>,
  handler?: (thrownValue: E, error: Error) => void
): Promise<Result<T, E>> {
  try {
    const value = await callback();
    return ok(value);
  } catch (originalError) {
    const error = toError(originalError);
    handler?.(originalError as E, error);
    return err(error as E);
  }
}

export function tryCatch<T, E = unknown>(
  callback: () => T,
  handler?: (thrownValue: E, error: Error) => void
): Result<T, E> {
  try {
    return ok(callback());
  } catch (originalError) {
    const error = toError(originalError);
    handler?.(originalError as E, error);
    return err(error as E);
  }
}

export async function runAppleScript(
  script: string,
) {
  return tryCatchAsync(async () => {
    const proc = Bun.spawn(['osascript', '-e', script.replace(/'/g, "'\\''")]);
    const text = await new Response(proc.stdout).text();
    return text;
  }, (__, error) => {
    console.error('Error executing AppleScript:', error.message);
  });
}

const Clipboard = {
read: () =>
  tryCatch(async () => {
    const proc = Bun.spawn(['pbpaste']);
    const text = await new Response(proc.stdout).text();
    return text;
    }, (__, error) => {
      console.error('Error getting clipboard:', error.message);
    }),
  write: (str: string) =>
    tryCatch(async () => {
      const proc = Bun.spawn(['pbcopy', '<', str]);
      const text = await new Response(proc.stdout).text();
      return text;
    }, (__, error) => {
      console.error('Error pasting clipboard:', error.message);
    }),
  clear: () =>
    tryCatch(async () => {
      const proc = Bun.spawn(['pbcopy', '<', '']);
      const text = await new Response(proc.stdout).text();
      return text;
    }, (__, error) => {
      console.error('Error clearing clipboard:', error.message);
    }),
}

async function pasteClipboard() {
  await runAppleScript(`tell application "System Events" to keystroke the clipboard as text`);
}


const utils = String.raw`
n findAndReplaceInText(theText, theSearchString, theReplacementString)
set AppleScript's text item delimiters to theSearchString
set theTextItems to every text item of theText
set AppleScript's text item delimiters to theReplacementString
set theText to theTextItems as string
set AppleScript's text item delimiters to ""
return theText
end findAndReplaceInText

script V
property Ps : missing value
property Ws : missing value
property JSON : ""
property Object : ""

to finalizeJSON()
	set JSON to "[" & text 1 thru -2 of JSON & "]"
end finalizeJSON

to addPair(key, value)
	set escapedValue to paragraphs of findAndReplaceInText(value, "\"", "\\\"")
	set Object to Object & ("\"" & key & "\":\"" & escapedValue) & "\","
end addPair

to finalizeObject()
	set Object to "{" & text 1 thru -2 of Object & "},"
	set JSON to JSON & Object
	set Object to ""
end finalizeObject
end script`

const getWindows = async () => {
  const result = await runAppleScript(String.raw`
${utils}

tell application "System Events"
  set V's Ps to processes whose visible is true

  repeat with theProcess in V's Ps
	  set V's Ws to window of theProcess
	  set counter to 0
	  repeat with theWindow in V's Ws
		  tell V to addPair("process", short name of theProcess as string)
		  tell V to addPair("title", name of theWindow as string)
		  tell V to addPair("index", counter as string)
		  set counter to counter + 1
		  tell V to finalizeObject()
	  end repeat
  end repeat

  tell V to finalizeJSON()
end tell

get V's JSON
`)

  return JSON.parse(result)
}
