import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = {title:'Mafia — Trust no one. Play together.',description:'Your friends. A few secrets. One very suspicious game night.'};
export default function RootLayout({children}:Readonly<{children:React.ReactNode}>){return <html lang="en"><body>{children}</body></html>}
