import { useState, useEffect } from "react";
import { format, addDays } from "date-fns";

export function useToday() {
  const [today, setToday] = useState(() => format(new Date(), "yyyy-MM-dd"));

  useEffect(() => {
    const handleFocus = () => {
      const now = format(new Date(), "yyyy-MM-dd");
      if (now !== today) setToday(now);
    };
    window.addEventListener("focus", handleFocus);
    return () => window.removeEventListener("focus", handleFocus);
  }, [today]);

  return today;
}

export function useTomorrow() {
  const [tomorrow, setTomorrow] = useState(() => format(addDays(new Date(), 1), "yyyy-MM-dd"));

  useEffect(() => {
    const handleFocus = () => {
      const now = format(addDays(new Date(), 1), "yyyy-MM-dd");
      if (now !== tomorrow) setTomorrow(now);
    };
    window.addEventListener("focus", handleFocus);
    return () => window.removeEventListener("focus", handleFocus);
  }, [tomorrow]);

  return tomorrow;
}
