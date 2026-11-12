import './globals.css';
import Navigation, { RoleProvider } from '@/components/Navigation';

export const metadata = {
  title: 'Omnichannel Attribution Engine',
  description: 'Multi-Touch Marketing Attribution Analytics Warehouse',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-slate-950 text-slate-100 antialiased">
        <RoleProvider>
          <Navigation />
          <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            {children}
          </main>
        </RoleProvider>
      </body>
    </html>
  );
}
