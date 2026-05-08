import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { UserProfile } from './user-profile';
import { AuthService } from '../../auth/auth.service';
import { UserService } from '../service/user-service';

describe('UserProfile', () => {
  let component: UserProfile;
  let fixture: ComponentFixture<UserProfile>;
  const authServiceStub = {
    currentUser$: of({
      id: 'u1',
      email: 'test@example.com',
      name: 'User Test',
    }),
    signOut: vi.fn().mockReturnValue(of(void 0)),
    updateCurrentUserName: vi.fn(),
  };
  const userServiceStub = {
    updateProfile: vi.fn().mockReturnValue(of({ id: 'u1', name: 'Updated' })),
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserProfile],
      providers: [
        { provide: AuthService, useValue: authServiceStub },
        { provide: UserService, useValue: userServiceStub },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(UserProfile);
    component = fixture.componentInstance;
    authServiceStub.signOut.mockClear();
    userServiceStub.updateProfile.mockClear();
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should call updateProfile on save', () => {
    component.handleSave({ name: '  Bruno  ', team: 'A' });

    expect(userServiceStub.updateProfile).toHaveBeenCalledWith({
      name: '  Bruno  ',
    });
  });

  it('should call signOut on logout', () => {
    component.logout();

    expect(authServiceStub.signOut).toHaveBeenCalled();
  });

  it('should handle updateProfile errors', () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    userServiceStub.updateProfile.mockReturnValueOnce(throwError(() => new Error('boom')));

    component.handleSave({ name: 'Any' });

    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });
});
