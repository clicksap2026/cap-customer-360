namespace crm;

using { cuid, managed } from '@sap/cds/common';

// Every time a sales rep talks to a customer: a call, a visit, an email or a meeting
entity Interactions : cuid, managed {
  customerID  : String(10)  @title: 'Customer' @mandatory;   // the S/4HANA business partner number
  @mandatory @assert.range
  type        : String(10)  @title: 'Type' enum { Call; Visit; Email; Meeting };
  contactDate : Date        @title: 'Date' @mandatory;
  summary     : String(500) @title: 'Summary' @mandatory;
  salesRep    : String(100) @title: 'Sales rep';
  followUp    : Date        @title: 'Follow up on';
}

// A deal we hope to win with a customer
entity Opportunities : cuid, managed {
  customerID : String(10)    @title: 'Customer' @mandatory;  // the S/4HANA business partner number
  title      : String(111)   @title: 'Title' @mandatory;
  value      : Decimal(12,2) @title: 'Value' @mandatory @assert.range: [0, 10000000];
  currency   : String(3)     @title: 'Currency' default 'EUR';
  @assert.range
  stage      : String(10)    @title: 'Stage' enum { Open; Won; Lost } default 'Open';
  closeDate  : Date          @title: 'Expected close';
}
