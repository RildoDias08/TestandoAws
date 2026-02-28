import React from "react";

/* ----------------------------- Utils ----------------------------- */
function cx(...classes: Array<string | undefined | false | null>) {
  return classes.filter(Boolean).join(" ");
}

/* ----------------------------- Badge ----------------------------- */
export function Badge({
  className,
  ...props
}: React.HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={cx(
        "inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium",
        className
      )}
      {...props}
    />
  );
}

/* ----------------------------- Button ---------------------------- */
export const Button = React.forwardRef<
  HTMLButtonElement,
  React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "default" | "outline" }
>(function Button({ className, variant = "default", ...props }, ref) {
  const base =
    "inline-flex items-center justify-center rounded-md px-3 py-2 text-sm font-medium transition disabled:opacity-50 disabled:pointer-events-none";
  const styles =
    variant === "outline"
      ? "border bg-transparent"
      : "bg-slate-900 text-white hover:opacity-90";
  return <button ref={ref} className={cx(base, styles, className)} {...props} />;
});

/* ------------------------------ Card ----------------------------- */
export function Card({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cx("rounded-lg border bg-white", className)} {...props} />
  );
}
export function CardHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cx("p-4 border-b", className)} {...props} />;
}
export function CardTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h3 className={cx("text-lg font-semibold", className)} {...props} />;
}
export function CardDescription({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cx("text-sm text-slate-600", className)} {...props} />;
}
export function CardContent({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cx("p-4", className)} {...props} />;
}

/* ----------------------------- Input ----------------------------- */
export const Input = React.forwardRef<
  HTMLInputElement,
  React.InputHTMLAttributes<HTMLInputElement>
>(function Input({ className, ...props }, ref) {
  return (
    <input
      ref={ref}
      className={cx(
        "h-10 w-full rounded-md border px-3 py-2 text-sm outline-none",
        className
      )}
      {...props}
    />
  );
});

/* ---------------------------- Skeleton --------------------------- */
export function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cx("animate-pulse rounded-md bg-slate-200", className)}
      {...props}
    />
  );
}

/* ------------------------------ Table ---------------------------- */
export function Table({ className, ...props }: React.TableHTMLAttributes<HTMLTableElement>) {
  return <table className={cx("w-full text-sm", className)} {...props} />;
}
export function TableHeader({ className, ...props }: React.HTMLAttributes<HTMLTableSectionElement>) {
  return <thead className={cx("border-b", className)} {...props} />;
}
export function TableBody({ className, ...props }: React.HTMLAttributes<HTMLTableSectionElement>) {
  return <tbody className={className} {...props} />;
}
export function TableRow({ className, ...props }: React.HTMLAttributes<HTMLTableRowElement>) {
  return <tr className={cx("border-b last:border-0", className)} {...props} />;
}
export function TableHead({ className, ...props }: React.ThHTMLAttributes<HTMLTableCellElement>) {
  return <th className={cx("px-3 py-2 text-left font-medium", className)} {...props} />;
}
export function TableCell({ className, ...props }: React.TdHTMLAttributes<HTMLTableCellElement>) {
  return <td className={cx("px-3 py-2", className)} {...props} />;
}

/* ------------------------------ Dialog --------------------------- */
type DialogCtx = { open: boolean; setOpen: (v: boolean) => void };
const DialogContext = React.createContext<DialogCtx | null>(null);

export function Dialog({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = React.useState(false);
  return (
    <DialogContext.Provider value={{ open, setOpen }}>
      {children}
    </DialogContext.Provider>
  );
}

export function DialogTrigger({
  children,
  asChild,
}: {
  children: React.ReactElement;
  asChild?: boolean;
}) {
  const ctx = React.useContext(DialogContext);
  if (!ctx) return children;
  const triggerProps = {
    onClick: (e: any) => {
      children.props?.onClick?.(e);
      ctx.setOpen(true);
    },
  };
  return asChild ? React.cloneElement(children, triggerProps) : (
    <button onClick={triggerProps.onClick}>{children}</button>
  );
}

export function DialogContent({
  className,
  children,
}: {
  className?: string;
  children: React.ReactNode;
}) {
  const ctx = React.useContext(DialogContext);
  if (!ctx || !ctx.open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      role="dialog"
      aria-modal="true"
    >
      <div
        className="absolute inset-0 bg-black/40"
        onClick={() => ctx.setOpen(false)}
      />
      <div className={cx("relative z-10 w-[min(92vw,520px)] rounded-lg border bg-white p-4", className)}>
        <button
          className="absolute right-3 top-3 text-slate-500 hover:text-slate-900"
          onClick={() => ctx.setOpen(false)}
          aria-label="Fechar"
        >
          ✕
        </button>
        {children}
      </div>
    </div>
  );
}

export function DialogHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cx("mb-3 space-y-1", className)} {...props} />;
}
export function DialogTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h2 className={cx("text-lg font-semibold", className)} {...props} />;
}
export function DialogDescription({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cx("text-sm text-slate-600", className)} {...props} />;
}
