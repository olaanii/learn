'use client';
import {
  UserGroupIcon,
  HomeIcon,
  DocumentDuplicateIcon,
} from '@heroicons/react/24/outline';
import NextLink from 'next/link';
import { usePathname } from 'next/navigation';
import clsx from 'clsx';
import type { SVGProps, ComponentType } from 'react';
type NavLink = {
  name: string;
  href: string;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
};
const Links: NavLink[] = [
  { name: 'Home', href: '/', icon: HomeIcon },
  { name: 'Documents', href: '/documents', icon: DocumentDuplicateIcon },
  { name: 'Users', href: '/users', icon: UserGroupIcon },
];
 
export default function NavLinks() {
    const pathname = usePathname();
  return (
    <>
      {Links.map((link) => {
        const LinkIcon = link.icon;
        return (
          <NextLink
            key={link.name}
            href={link.href}
            className={clsx(
              'flex h-[48px] grow items-center justify-center gap-2 rounded-md bg-gray-50 p-3 text-sm font-medium hover:bg-sky-100 hover:text-blue-600 md:flex-none md:justify-start md:p-2 md:px-3',
              {
                'bg-sky-100 text-blue-600': pathname === link.href,
              },
            )}
            >
            <LinkIcon className="w-6" />
            <p className="hidden md:block">{link.name}</p>
          </NextLink>
        );
      })}
    </>
  );
}