ibolt_size : dialog {
  label = "Dynamic Bolt";
  : text {
    label = "Choose the bolt standard and nominal size.";
    alignment = centered;
  }
  spacer;
  : boxed_column {
    label = "Bolt standard";
    : radio_row {
      : radio_button {
        key = "metric";
        label = "Metric (M sizes)";
      }
      : radio_button {
        key = "imperial";
        label = "Imperial (inch sizes)";
      }
    }
  }
  : boxed_column {
    label = "Nominal bolt size";
    : popup_list {
      key = "metric_size";
      label = "Metric:";
      width = 30;
    }
    : popup_list {
      key = "imperial_size";
      label = "Imperial:";
      width = 30;
    }
  }
  spacer;
  : text {
    label = "The selected plate-face spacing controls the head-to-nut grip.";
    alignment = centered;
  }
  spacer;
  ok_cancel;
}
