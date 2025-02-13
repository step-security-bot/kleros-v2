import { useState } from "react";

export function useSessionStorage<T>(keyName: string, defaultValue: T) {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const value = window.sessionStorage.getItem(keyName);

      return value ? JSON.parse(value) : defaultValue;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.log("useSessionStorage:", { err });

      return defaultValue;
    }
  });

  const setValue = (newValue: T) => {
    try {
      window.sessionStorage.setItem(keyName, JSON.stringify(newValue));
    } finally {
      setStoredValue(newValue);
    }
  };

  return [storedValue, setValue] as [T, (newValue: T) => void];
}
