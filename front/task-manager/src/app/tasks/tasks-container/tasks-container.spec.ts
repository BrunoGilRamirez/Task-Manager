import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { of, throwError } from 'rxjs';

import { TasksContainer } from './tasks-container';
import { TaskService } from '../service/task-service';
import type { Task } from '../models/task.model';

describe('TasksContainer', () => {
  let component: TasksContainer;
  let fixture: ComponentFixture<TasksContainer>;
  let taskService: TaskService;
  const loadingSignal = signal(false);
  const paginationSignal = signal({ page: 1, pageSize: 20, count: 2, totalPages: 1 });
  const tasksSignal = signal<Task[]>([
    {
      id: 1,
      title: 'Task 1',
      description: 'Desc',
      completed: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: 2,
      title: 'Task 2',
      description: 'Desc',
      completed: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ]);

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TasksContainer],
      providers: [
        {
          provide: TaskService,
          useValue: {
            tasks: tasksSignal,
            loading: loadingSignal,
            pagination: paginationSignal,
            addTask: vi.fn().mockReturnValue(of({})),
            refreshTasks: vi.fn(),
            setPage: vi.fn(),
            setSort: vi.fn(),
            getTasksSnapshot: vi.fn(() => tasksSignal()),
            removeTaskFromStore: vi.fn(),
            deleteTask: vi.fn().mockReturnValue(of({})),
            restoreTasks: vi.fn(),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(TasksContainer);
    component = fixture.componentInstance;
    taskService = TestBed.inject(TaskService);
    loadingSignal.set(false);
    paginationSignal.set({ page: 1, pageSize: 20, count: 2, totalPages: 1 });
    tasksSignal.set([
      {
        id: 1,
        title: 'Task 1',
        description: 'Desc',
        completed: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: 2,
        title: 'Task 2',
        description: 'Desc',
        completed: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should filter completed tasks', () => {
    component.setFilter('completed');

    expect(component.filteredTasks().every((task) => task.completed)).toBe(true);
  });

  it('should toggle create form and reset when closing', () => {
    component.toggleCreateForm();
    component.createForm.patchValue({ title: 'Task', description: 'Desc' });

    component.toggleCreateForm();

    expect(component.showCreateForm()).toBe(false);
    expect(component.createForm.value.title).toBe('');
  });

  it('should create task and refresh list', () => {
    component.toggleCreateForm();
    component.createForm.patchValue({ title: ' New ', description: ' Desc ' });

    component.createTask();

    expect(taskService.addTask).toHaveBeenCalledWith({
      title: 'New',
      description: 'Desc',
      completed: false,
    });
    expect(taskService.refreshTasks).toHaveBeenCalledWith(true);
  });

  it('should not create task when form is invalid', () => {
    component.createForm.patchValue({ title: '' });

    component.createTask();

    expect(taskService.addTask).not.toHaveBeenCalled();
  });

  it('should rollback on delete error', () => {
    const previousTasks = taskService.getTasksSnapshot();
    (taskService.deleteTask as any).mockReturnValue(throwError(() => new Error('Boom')));

    component.deletingTask(1);

    expect(taskService.removeTaskFromStore).toHaveBeenCalledWith(1);
    expect(taskService.restoreTasks).toHaveBeenCalledWith(previousTasks);
  });

  it('should set sorting on task service', () => {
    component.setSort('title_asc');

    expect((taskService as any).setSort).toHaveBeenCalledWith('title', 'asc');
  });

  it('should render empty state when there are no tasks and not loading', async () => {
    tasksSignal.set([]);
    loadingSignal.set(false);
    fixture.detectChanges();
    await fixture.whenStable();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('.empty-state p')?.textContent).toContain('No tasks to display');
  });
});
