using Customer360Service from '../srv/customer360-service';

// Columns for the Fiori preview
annotate Customer360Service.Interactions with @(UI.LineItem: [
  { Value: customerID },
  { Value: type },
  { Value: contactDate },
  { Value: summary },
  { Value: salesRep },
  { Value: followUp }
]);

annotate Customer360Service.Opportunities with @(UI.LineItem: [
  { Value: customerID },
  { Value: title },
  { Value: value },
  { Value: currency },
  { Value: stage },
  { Value: closeDate }
]);
