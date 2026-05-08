import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { Router } from '@angular/router';

import { Sidebar } from './sidebar';
import { TaskService } from '../../tasks/service/task-service';
import type { Task } from '../../tasks/models/task.model';

describe('Sidebar', () => {
  let component: Sidebar;
  let fixture: ComponentFixture<Sidebar>;
  const tasksSignal = signal<Task[]>([
    {
      id: 1,
      title: 'Task A',
      description: 'Desc',
      completed: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: 2,
      title: 'Task B',
      description: 'Desc',
      completed: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: 3,
      title: 'Task C',
      description: 'Desc',
      completed: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ]);
  const taskServiceStub = {
    tasks: tasksSignal,
  };
  const routerStub = {
    navigate: vi.fn(),
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Sidebar],
      providers: [
        { provide: TaskService, useValue: taskServiceStub },
        { provide: Router, useValue: routerStub },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(Sidebar);
    component = fixture.componentInstance;
    tasksSignal.set([
      {
        id: 1,
        title: 'Task A',
        description: 'Desc',
        completed: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: 2,
        title: 'Task B',
        description: 'Desc',
        completed: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: 3,
        title: 'Task C',
        description: 'Desc',
        completed: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
    routerStub.navigate.mockClear();
    fixture.componentRef.setInput('mode', 'container');
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should calculate sidebar counters', () => {
    expect(component.totalCount()).toBe(3);
    expect(component.pendingCount()).toBe(2);
    expect(component.completedCount()).toBe(1);
  });

  it('should show empty state in details mode when there are no tasks', async () => {
    tasksSignal.set([]);
    fixture.componentRef.setInput('mode', 'details');
    fixture.detectChanges();
    await fixture.whenStable();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.task-list-empty')?.textContent).toContain(
      'No tasks to display',
    );
  });
});
