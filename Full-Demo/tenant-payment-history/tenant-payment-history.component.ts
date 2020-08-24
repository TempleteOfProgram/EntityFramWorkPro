import { Component, OnInit, ViewChild, ChangeDetectorRef, OnDestroy, ViewChildren, QueryList, EventEmitter, Output} from '@angular/core';
import { PaymentService } from '@lms/admin/app/modules/payment/services/payment.service';
import { PaymentHistoryModel } from '@lms/admin/app/modules/payment/models/payment-history.model';
import { ActivatedRoute, Router } from '@angular/router';
import { MatTableDataSource, MatPaginator, MatSort } from '@angular/material';
import { FormControl } from '@angular/forms';
import { ConfigApiService } from '@lms/common/lib/config/services/config-api.service';
import { ConfigType } from '@lms/common/lib/models/config';
import { Subscription, merge, Subject, Observable } from 'rxjs';
import { debounceTime, startWith, filter, switchMap, takeUntil } from 'rxjs/operators';
import { PaymentSearchModel } from '@lms/admin/app/modules/search/models/payment-search.model';
import { SelectComponent } from '@lms/admin/app/shared/components/select/select.component';
import { ExcelPaymentModel } from '@lms/admin/app/modules/payment/models/tenant-payments-models/excel-payment.model';
import { PaymentStatusEnum} from 'libs/common/src/lib/enums/payment-status.enum'; 
import { SidenavWrapperComponent } from '@lms/common/app/shared/components/sidenav/sidenav-wrapper.component';
import { SidenavService } from '@lms/common/app/shared/components/sidenav/sidenav.service';
import { CommonService } from '@lms/common/lib/services/common.service';
import moment from 'moment';


@Component({
  selector: 'lms-tenant-payment-history',
  templateUrl: './tenant-payment-history.component.html',
  styleUrls: ['./tenant-payment-history.component.scss']
})
export class TenantPaymentHistoryComponent implements OnInit, OnDestroy {
  
  minDate = new Date('1/1/1900');
  today: Date = this.commonService.currentDate;
 
  tenantId: number;
  hasData: boolean= false;
  isLoading: boolean = false;
  clearingFilter: boolean = false;
  paymentCodes: ConfigType[];
  paymentStatusTypes: ConfigType[];
  numberOfPayments: number;
  searchModel: PaymentSearchModel;
  payments: PaymentHistoryModel[];
  isKeyboardDateRange: boolean = false;
  hasScheduledPayment: boolean = false;
  selectingPaymentStatue: boolean = false;
  public selRowIndex: number = null;
  @Output() details: EventEmitter<any> = new EventEmitter();
  private _destroyed$ = new Subject();
  
  private dateRange: FormControl = new FormControl();
  private isScheduledPayment: FormControl = new FormControl();  
  private subscriptions: Subscription = new Subscription;
  private searchText: FormControl = new FormControl; 
  private dataSource: MatTableDataSource<PaymentHistoryModel>;
  @ViewChildren('picker') dateRangePicker;
  @ViewChildren('SelectPaymentCode') SelectPaymentCode: QueryList<SelectComponent>;
  @ViewChildren('SelectPaymentStatus') SelectPaymentStatus: QueryList<SelectComponent>;
  @ViewChild(SidenavWrapperComponent, { static: true }) sidenavWrapper: SidenavWrapperComponent; 

  private greenPaymentStatues = ["Paid"];
  private bluePaymentStatues  = ["Scheduled"];
  private yellowPaymentStatues= ["Pending Issuance", "Outstanding", "Issued"]
  private redPaymentStatuses  = ["WMS Error", "Rejected", "Stop", "Void", "Cancelled", "Stale"];
  private displayedColumns: string[] = ['wmsCaseNumber', 'paymentDate', 'paymentPeriod', 'amount', 'paymentCode', 'checkNumber', 'payee', 'status'];
  paymentDetailsPanelOpen: boolean = false;
  selectedResult: any;

  // dynamic pagination set up
  @ViewChild(MatPaginator, {static: false}) 
  set paginator(value: MatPaginator) {
    if(this.dataSource)
      this.dataSource.paginator = value; 
  }
  // dynamic sort set up
  @ViewChild(MatSort, {static: false}) 
  set sort(value: MatSort) {
    if(this.dataSource)
      this.dataSource.sort = value;
  }

  constructor(private paymentService: PaymentService,
              private activatedRoute: ActivatedRoute,
              private apiConfig: ConfigApiService,
              private cdRef: ChangeDetectorRef, 
              public sidenavService: SidenavService,
              private commonService: CommonService,
              private router: Router) { 
                 // LME-492
  }

  ngOnInit() {
    this.getConfigs();
    this.initialDataLoad();
    this.initSearchModel();
    const isSchedulePaymentSub = this.isScheduledPayment.valueChanges.pipe(debounceTime(500)).subscribe(value => {
      if(!this.selectingPaymentStatue){
        this.filteredDataLoad(value, 'Scheduled');
      }
      this.selectingPaymentStatue=false;
       
    });
    const dateRangeSub = this.dateRange.valueChanges.pipe(debounceTime(500)).subscribe(range => {
      this.dateRangePicker.rangeMode = true;
      if(range && range['begin'] && !this.isKeyboardDateRange){
        if(range['begin'].isValid()){
          this.searchModel.fromDate = new Date(range['begin'])
        }
        if(range['end'] && range['end'].isValid()){
          const fromDate = this.GetFormattedDate(new Date(range['begin']), null);
          const toDate = this.GetFormattedDate(new Date(range['end']), null);
          if(fromDate.localeCompare(toDate) != 0){
            // range mode: has  begin and end moments type
            this.searchModel.toDate = new Date(range['end']);
          }else{
            // single date mode: has only one moment type
            this.searchModel.toDate = null;
            this.dateRangePicker.rangeMode = false; 
            this.dateRangePicker['_results'][0]['endDate'] = null;
            this.dateRange.setValue(null); // clear control
            this.dateRange.setValue(moment(fromDate, 'MM/DD/YYYY', true)); // set control
            if (!this.cdRef['destroyed']) this.cdRef.detectChanges();
          }
        }
        if(range['begin'].isValid() || !this.dateRangePicker.rangeMode){
          this.filteredDataLoad('value', 'dateRange')
        }
      } 
  });         
    const searchTextSub = this.searchText.valueChanges.pipe(debounceTime(500)).subscribe(value => this.filteredDataLoad(value, 'keyword'));              
    this.subscriptions.add(dateRangeSub);
    this.subscriptions.add(searchTextSub);
    this.subscriptions.add(isSchedulePaymentSub);
  }

  updatePaymentStatues(event){
    this.selectingPaymentStatue = true;
    this.filteredDataLoad(event, 'paymentStatue')
  }

  getConfigs(){
    const configSub =this.apiConfig.getConfigTypes().subscribe((configs: ConfigType[]) => { 
      this.paymentCodes = configs.filter(config => config.configType == "PaymentCode" && config.name.localeCompare('B7') != 0); 
      this.paymentStatusTypes = configs.filter(config => config.configType == "PaymentStatus" && config.name.localeCompare('Ended') != 0);
    });
    this.subscriptions.add(configSub);
  }

 initialDataLoad(){
  this.payments = [];
  this.isLoading = this.clearingFilter == true ? false: true;
  this.hasScheduledPayment = false;
  this.activatedRoute.params.subscribe(({ tenantId }) => { this.tenantId = +tenantId; 
    let model = new PaymentSearchModel();
    model.tenantId = this.tenantId;
    this.paymentService.SearchPayments(model).subscribe((payments: PaymentHistoryModel[]) =>{
      payments.forEach(payment =>{
        if(payment.status.localeCompare('Scheduled') == 0){ this.hasScheduledPayment = true;};
        if(this.greenPaymentStatues.includes(payment.status)){
          payment.color = "green";
        }else if(this.bluePaymentStatues.includes(payment.status)){
          payment.color = "blue";
        }else if(this.redPaymentStatuses.includes(payment.status)){
          payment.color = "red";
        }else{
          payment.color = "yellow";
        }
      });
      this.payments = payments.filter(payment => payment.status.localeCompare('Ended') != 0);
      this.hasData = this.payments.length > 0 ? true : false;
      // do not show Scheduled payment on initial load
      this.payments = this.payments.filter(payment => payment.status.localeCompare('Scheduled') != 0);
      this.numberOfPayments = this.payments.length;
      
      this.dataSource = new MatTableDataSource<PaymentHistoryModel>(this.payments);
      this.dataSource.paginator = this.paginator;
      this.dataSource.sort = this.sort;
      this.clearingFilter = false;
      this.isLoading = false;
      if (!this.cdRef['destroyed']) this.cdRef.detectChanges();
    });
  });
 }

 filteredDataLoad(value, property) {
  this.payments = [];
  this.hasScheduledPayment = false;
   switch(property){
     case 'keyword':
      this.searchModel.keyword = value ? value.trim().toLowerCase(): '';
      break;
    case 'paymentCode':
      this.searchModel.paymentCodeType = value;
      break;
    case 'paymentStatue':
      this.searchModel.paymentStatusType = value; 
      // auto select scheduled check box if only scheduled status is seleced from 
      // payment status dropdown
      if(value && value.length == 1 && value.includes(PaymentStatusEnum.Scheduled)){
        this.searchModel.isScheduled = true;
        this.isScheduledPayment.setValue(true);
      } 
      else{
        this.searchModel.isScheduled = false;
        this.isScheduledPayment.setValue(false)
      }
      break;
    case 'dateRange':
      // this.searchModel.fromDate = this.fromDate;
      // this.searchModel.toDate = this.toDate;
      break;
    case 'Scheduled':
      this.searchModel.isScheduled = value;
      this.searchModel.paymentStatusType = [];
      this.SelectPaymentStatus.last.selection.setValue([]);
      if(value===true){ // scheduled chech box was checked
        this.SelectPaymentStatus.last.selection.setValue([PaymentStatusEnum.Scheduled]);
      }
      break;
   } 
   if(!this.clearingFilter){
    this.paymentService.SearchPayments(this.searchModel).subscribe((payments: PaymentHistoryModel[]) =>{
      payments.forEach(payment =>{
          if(payment.status.localeCompare('Scheduled') == 0){ this.hasScheduledPayment = true;};
          if(this.greenPaymentStatues.includes(payment.status)){
            payment.color = "green";
          }else if(this.bluePaymentStatues.includes(payment.status)){
            payment.color = "blue";
          }else if(this.redPaymentStatuses.includes(payment.status)){
            payment.color = "red";
          }else{
            payment.color = "yellow";
          }
        });
        this.payments = payments.filter(payment => payment.status.localeCompare('Ended') != 0);
        
        if((this.searchModel.paymentStatusType && this.searchModel.paymentStatusType.length > 1 && !this.searchModel.paymentStatusType.includes(PaymentStatusEnum.Scheduled)) ||
        (this.searchModel.paymentStatusType && this.searchModel.paymentStatusType.length == 0 && (this.isScheduledPayment.value == null|| this.isScheduledPayment.value == false))){
            this.payments = this.payments.filter(payment => payment.status.localeCompare('Scheduled') != 0)
         }

        this.numberOfPayments = this.payments.length;
  
        this.dataSource = new MatTableDataSource<PaymentHistoryModel>(this.payments);
        this.dataSource.paginator = this.paginator;
        this.dataSource.sort = this.sort;
        if (!this.cdRef['destroyed']) this.cdRef.detectChanges();
     });
   } 
}

initSearchModel(){
    this.searchModel = new PaymentSearchModel();
    this.searchModel.tenantId = this.tenantId;
}

clearAll() {
  this.clearingFilter = true;
  this.searchText.setValue(null);
  this.dateRange.setValue(null);
  this.isScheduledPayment.setValue(null);
  if(this.SelectPaymentCode && this.SelectPaymentCode.last && this.SelectPaymentCode.last.selection)
    this.SelectPaymentCode.last.selection.setValue([]);
  if(this.SelectPaymentStatus  && this.SelectPaymentStatus.last && this.SelectPaymentStatus.last.selection)
    this.SelectPaymentStatus.last.selection.setValue([]);
  if (!this.cdRef['destroyed']) this.cdRef.detectChanges();
  this.initSearchModel();
  this.initialDataLoad();
}

exportExcel() {
  if(this.numberOfPayments > 0){
    var excelPaymentModelArray: ExcelPaymentModel[] = [];
    this.payments.forEach(payment =>{
      var excelRow = new ExcelPaymentModel();
      excelRow.wmsCaseNumber = payment.wmsCaseNumber ? payment.wmsCaseNumber : 'N/A';
      excelRow.paymentDate = payment.paymentDate ? payment.paymentDate : 'N/A';
      excelRow.paymentPeriod = payment.paymentPeriod ? payment.paymentPeriod : 'N/A';
      excelRow.amount = payment.amount ? payment.amount : 'N/A';
      excelRow.paymentCode = payment.paymentCode ? payment.paymentCode : 'N/A';
      excelRow.checkNumber = payment.checkNumber ? payment.checkNumber : 'N/A';
      excelRow.payee = payment.payee ? payment.payee : 'N/A';
      excelRow.status = payment.status ? payment.status : 'N/A';
      excelPaymentModelArray.push(excelRow);
    });
    //If excelPaymentModelArray is not an object then JSON.parse will parse the JSON string in an Object
    var arrData = typeof excelPaymentModelArray != 'object' ? JSON.parse(excelPaymentModelArray) : excelPaymentModelArray;
    var CSV = 'sep=,' + '\r';
    var row = "" 
  
    // creating levels of the csv file
    for (var index in arrData[0]) { 
      switch(index){
        case 'wmsCaseNumber':
          index = 'WMS Case #  '
          break;
        case 'paymentDate':
          index = 'Date Issued  '
          break;
        case 'paymentPeriod':
          index = 'Payment Period  '
          break;
        case 'amount':
          index = 'Amount'
          break;
        case 'paymentCode':
          index = 'Payment Code  '
          break;
        case 'checkNumber':
          index = 'Check Number  '
          break;
        case 'tenantName':
          index = 'Tenant Name  '
          break;
        case 'payee':
          index = 'Payee  '
          break;
        case 'status':
          index = 'Status  '
          break;
      }
      row += index + ',  '; 
    }
    row = row.slice(0, -1);
    CSV += row + '\r\n';
  
    // inserting value for each column and row
    for (var i = 0; i < arrData.length; i++) {
        var row = "";
        for (var index in arrData[i]) {
          row += '"' + arrData[i][index] + '",';
        }
        row.slice(0, row.length - 1);
        CSV += row + '\r\n';
    }
    if (CSV == '') { alert("Invalid data"); return;}
  
    var fileName = "Payments" + this.tenantId.toString();  
    var uri = 'data:text/csv;charset=utf-8,' + escape(CSV);
    var link = document.createElement("a");    
    link.href = uri;
    link.download = fileName + ".csv";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }  
} 

navigateToPayee(userId){
  // landlord/details/userId
  if(userId)
    this.router.navigate([`landlord/details/${userId}`]);
}
openDetails(payment){
  if(this.selRowIndex === payment.paymentDetailId){
    this.selRowIndex = null;
    this.sidenavService.close();
  }
  else{
    this.selRowIndex = payment.paymentDetailId;
    this.selectedResult = payment;
    if (!this.cdRef['destroyed']) this.cdRef.detectChanges();
    if (!this.selectedResult) this.sidenavService.close();
    else this.openPaymentDetailsPanel().subscribe();
  }
}

openPaymentDetailsPanel(): Observable<any> {
  const sideNavOptions = { isCollapsible: false, isCloseable: true };
  return this.sidenavService.open$(this.sidenavWrapper, sideNavOptions);
}

keyBoardEvent(event) {
  if(event.inputType=='insertText') {
      this.isKeyboardDateRange = true;
      const link = document.querySelector('#keyboardDateRange');
      if (link) {
          const values = link['value'];
          if (!values) return;
          if(typeof values == 'string'){
            const dates = values.split("-") // '8/25/2020 - 10/25/2020'
            if (dates.length < 1 || dates.length > 2) return null; 
            const startDate = new Date(dates[0].trim());
            const fStartDate = this.GetFormattedDate(startDate, null);
            const isValidStartDate = moment(fStartDate, 'MM/DD/YYYY',true).isValid() && startDate >= this.minDate;
            if(isValidStartDate)
              this.searchModel.toDate = startDate;
            const endDate = dates.length == 2 ?  new Date(dates[1].trim()) : null;
            const fEndDate = endDate ? this.GetFormattedDate(endDate, null) : null;
            const isValidEndDate = fEndDate ? moment(fEndDate, 'MM/DD/YYYY',true).isValid() && endDate >= this.minDate: false;
            if(isValidEndDate)
              this.searchModel.toDate = endDate;
            if(isValidStartDate || isValidEndDate)
              this.filteredDataLoad('value', 'dateRange')
          };
      }
  }
  else {
    this.isKeyboardDateRange = false;
  }
}


GetFormattedDate(date: Date, formate: string) {
  var month = (date.getMonth() + 1).toString();
  var day = (date.getDate()).toString();
  const year = date.getFullYear().toString();
  if (parseInt(day) < 10) { day = "0" + day }
  if (parseInt(month) < 10) { month = "0" + month }
  if (formate == "mm-dd-yyyy")
    return month + "-" + day + "-" + year;
  else //formate=="mm/dd/yyyy"
    return month + "/" + day + "/" + year;
}

get paginationOptions(){
  return  [10, 25, this.numberOfPayments]
 }

ngOnDestroy() {
  this.subscriptions.unsubscribe()
  this._destroyed$.next();
  this.sidenavService.close();
}

}


