import { useContext, useLayoutEffect, useMemo, useReducer, useRef } from "react";
import { DataCtx } from "@/providers/DataProvider";
import { DataContextProps } from "@/types/DataProviderTypes";

/**
 * Komponen hanya render ulang kalau field yang DIPAKAINYA berubah.
 * Dulu setiap update (speedometer 10x/detik) membuat semua 19 komponen ikut render ulang.
 * Field yang dibaca saat render dicatat lewat Proxy; fungsi dibungkus supaya selalu memanggil versi terbaru.
 */
const useData = (): DataContextProps => {
  const store = useContext(DataCtx);
  const [, forceRender] = useReducer((c: number) => c + 1, 0);
  const used = useRef(new Map<string, unknown>());
  const fns = useRef<Record<string, (...args: any[]) => any>>({});

  used.current.clear(); // dicatat ulang di render ini

  useLayoutEffect(() => {
    const check = () => {
      for (const [key, value] of used.current) {
        if (!Object.is((store.value as any)[key], value)) {
          forceRender();
          return;
        }
      }
    };
    store.listeners.add(check);
    check(); // perubahan di antara render dan subscribe
    return () => {
      store.listeners.delete(check);
    };
  }, [store]);

  return useMemo(
    () =>
      new Proxy({} as DataContextProps, {
        get(_, key: string) {
          const value = (store.value as any)[key];
          if (typeof value === "function") {
            return (fns.current[key] ??= (...args: any[]) => (store.value as any)[key](...args));
          }
          used.current.set(key, value);
          return value;
        },
      }),
    [store]
  );
};

export default useData;
