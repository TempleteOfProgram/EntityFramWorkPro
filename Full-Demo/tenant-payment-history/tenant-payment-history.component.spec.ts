import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { TenantPaymentHistoryComponent } from './tenant-payment-history.component';

describe('TenantPaymentHistoryComponent', () => {
  let component: TenantPaymentHistoryComponent;
  let fixture: ComponentFixture<TenantPaymentHistoryComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ TenantPaymentHistoryComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(TenantPaymentHistoryComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
