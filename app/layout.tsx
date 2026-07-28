import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Osteq",
  description: "Osteq trade platform",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
