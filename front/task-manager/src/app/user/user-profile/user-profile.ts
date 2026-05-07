import { AsyncPipe } from '@angular/common';
import { Component, inject } from '@angular/core';
import { AuthService } from '../../auth/auth.service';
import { UserProfileSummary } from '../profile-summary/profile-summary';
import { UserProfileForm } from '../profile-form/profile-form';
import { UserProfileSecurity } from '../profile-security/profile-security';
import type { ProfileFormValue } from '../profile-form/profile-form';
import { UserService } from '../service/user-service';
import { AuthUser } from '../../auth/models/auth.model';

/**
 * Container component for the authenticated user's profile view and actions.
 */
@Component({
  selector: 'app-user-profile',
  imports: [AsyncPipe, UserProfileSummary, UserProfileForm, UserProfileSecurity],
  templateUrl: './user-profile.html',
  styleUrl: './user-profile.css',
})
export class UserProfile {
  private authService = inject(AuthService);
  private userService = inject(UserService);

  user$ = this.authService.currentUser$;

  /**
   * Persists profile changes through `UserService`.
   */
  handleSave(payload: ProfileFormValue): void {
    this.userService.updateProfile({ name: payload.name }).subscribe({
      next: (updatedUser: AuthUser) => {
        this.authService.updateCurrentUserName(updatedUser.name ?? '');
      },
      error: (error) => {
        console.error('Failed to update profile:', error);
      },
    });
  }

  /**
   * Handles cancellation of profile edits.
   */
  handleCancel(): void {
    // TODO: Hook to reset any parent-level edit state if needed.
    console.log('Profile edit canceled');
  }

  /**
   * Signs out the current user session.
   */
  logout(): void {
    this.authService.signOut().subscribe();
  }
}
