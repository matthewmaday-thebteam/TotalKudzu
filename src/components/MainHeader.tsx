import { useState, useRef, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Avatar } from './Avatar';
import { ProfileEditorModal } from './ProfileEditorModal';

export type NavRoute = 'home' | 'users';

interface MainHeaderProps {
  activeRoute: NavRoute;
  onRouteChange: (route: NavRoute) => void;
}

export function MainHeader({ onRouteChange }: MainHeaderProps) {
  const { user, signOut } = useAuth();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // Close menu on outside click
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsMenuOpen(false);
      }
    };

    if (isMenuOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isMenuOpen]);

  const handleSignOut = async () => {
    setIsMenuOpen(false);
    await signOut();
  };

  const handleOpenProfile = () => {
    setIsMenuOpen(false);
    setIsProfileModalOpen(true);
  };

  // Get display name from user metadata or email
  const firstName = user?.user_metadata?.first_name || '';
  const lastName = user?.user_metadata?.last_name || '';
  const avatarUrl = user?.user_metadata?.avatar_url || null;

  let formattedName: string;
  if (firstName || lastName) {
    formattedName = [firstName, lastName].filter(Boolean).join(' ');
  } else {
    // Fallback to email-based name
    const displayName = user?.email?.split('@')[0] || 'User';
    formattedName = displayName
      .split(/[._-]/)
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  return (
    <header className="h-14 bg-white border-b border-vercel-gray-100">
      <div className="max-w-7xl mx-auto px-6 h-full flex items-center justify-between">
        {/* Left: Logo/Brand */}
        <div className="flex items-center">
          <span className="text-lg font-semibold text-vercel-gray-600">TotalKudzu</span>
        </div>

        {/* Right: Avatar with Dropdown */}
        <div className="flex items-center gap-4">
          <div className="relative" ref={menuRef}>
            <button
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="focus:outline-none focus:ring-1 focus:ring-black rounded-full"
            >
              <Avatar name={formattedName} size={32} src={avatarUrl} />
            </button>

            {isMenuOpen && (
              <div
                className="absolute right-0 mt-2 w-56 bg-white rounded-lg border border-vercel-gray-100 overflow-hidden z-50"
                style={{
                  boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06), 0 0 0 1px rgba(0, 0, 0, 0.05)',
                }}
              >
                {/* User Info */}
                <div className="px-4 py-3 border-b border-vercel-gray-100">
                  <p className="text-sm font-medium text-vercel-gray-600">{formattedName}</p>
                  <p className="text-xs text-vercel-gray-400 truncate">{user?.email}</p>
                </div>

                {/* Menu Items */}
                <div className="py-1">
                  <button
                    onClick={handleOpenProfile}
                    className="w-full px-4 py-2 text-left text-sm text-vercel-gray-600 hover:bg-vercel-gray-50 transition-colors flex items-center gap-2"
                  >
                    <svg className="w-4 h-4 text-vercel-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                    Profile
                  </button>
                  <button
                    onClick={() => {
                      setIsMenuOpen(false);
                      onRouteChange('users');
                    }}
                    className="w-full px-4 py-2 text-left text-sm text-vercel-gray-600 hover:bg-vercel-gray-50 transition-colors flex items-center gap-2"
                  >
                    <svg className="w-4 h-4 text-vercel-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                    User Management
                  </button>
                  <button
                    onClick={handleSignOut}
                    className="w-full px-4 py-2 text-left text-sm text-vercel-gray-600 hover:bg-vercel-gray-50 transition-colors flex items-center gap-2"
                  >
                    <svg className="w-4 h-4 text-vercel-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                    </svg>
                    Sign Out
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Profile Editor Modal */}
      <ProfileEditorModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
      />
    </header>
  );
}
