using Customer360Service from '../srv/customer360-service';

// Columns for the Fiori preview
annotate Customer360Service.Interactions with @(UI.LineItem: [
  { Value: customerID },
  { Value: customerName },
  { Value: type },
  { Value: contactDate },
  { Value: summary },
  { Value: salesRep },
  { Value: followUp }
]);

annotate Customer360Service.Opportunities with @(UI.LineItem: [
  { Value: customerID },
  { Value: customerName },
  { Value: title },
  { Value: value },
  { Value: currency },
  { Value: stage },
  { Value: closeDate }
]);

annotate Customer360Service.Customers with @(UI.LineItem: [
  { Value: ID,        Label: 'Customer' },
  { Value: name,      Label: 'Name' },
  { Value: industry,  Label: 'Industry' },
  { Value: createdOn, Label: 'Created on' }
]);
