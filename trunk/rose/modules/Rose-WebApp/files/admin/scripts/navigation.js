Menu = new Array();

function menuItemGo()
{
  var w = window.open(this.url, this.name, this.features, this.replace);
  w.focus();
  return false;
}

function menuItemToString()
{
  return  "url: " + this.url + "\n" +
          "name: " + this.name + "\n" +
          "features: " + this.features + "\n" +
          "replace: " + this.replace + "\n";
}

function MenuItem(url, name, features, replace)
{
  // Properties
  this.url      = url;
  this.name     = name || '_top';
  this.features = features;
  this.replace  = replace;

  // Methods
  this.go       = menuItemGo;
  this.toString = menuItemToString;
}

Menu[0] = new MenuItem('/searches', '', '', '');
Menu[1] = new MenuItem('/searches/customer_search.perl', '', '', '');
Menu[2] = new MenuItem('/searches/client_search.perl', '', '', '');
Menu[3] = new MenuItem('/searches/cc_search.perl', '', '', '');
Menu[4] = new MenuItem('/searches/op_search.perl', '', '', '');
Menu[5] = new MenuItem('/searches/wg_event_search.perl', '', '', '');
Menu[6] = new MenuItem('/searches/mpg_search.perl', '', '', '');
Menu[7] = new MenuItem('/searches/mpg_reports.perl', '', '', '');
Menu[8] = new MenuItem('/searches/mp_tourney.perl', '', '', '');
Menu[9] = new MenuItem('/searches/req_log_search.perl', '', '', '');
Menu[10] = new MenuItem('/services', '', '', '');
Menu[11] = new MenuItem('http://rtdev2.grandvirtual.com', 'RT', '', '');
Menu[12] = new MenuItem('http://fidel.grandvirtual.com:8005/cgi-bin/pva.cgi', 'PVA', '', '');
Menu[13] = new MenuItem('/services/Mailing%20List%20Admin%20%28NOT%20IMPLEMENTED%29', '', '', '');
Menu[14] = new MenuItem('/services/Personal%20Messaging%20%28NOT%20IMPLEMENTED%29', '', '', '');
Menu[15] = new MenuItem('http://gv.grandvirtual.com/cgi-bin/geolocate', 'GEO', '', '');
Menu[16] = new MenuItem('/finops', '', '', '');
Menu[17] = new MenuItem('/finops/new_batch.perl', '', '', '');
Menu[18] = new MenuItem('/finops/postproc.perl', '', '', '');
Menu[19] = new MenuItem('/finops/ban_purchase_methods.perl', '', '', '');
Menu[20] = new MenuItem('/finops/choose_cheque_batch.perl', '', '', '');
Menu[21] = new MenuItem('/finops/choose_otherpay_batch.perl', '', '', '');
Menu[22] = new MenuItem('/finops/profit.perl', '', '', '');
Menu[23] = new MenuItem('/finops/chargeback.perl', '', '', '');
Menu[24] = new MenuItem('/finops/rtm_volume.perl', '', '', '');
Menu[25] = new MenuItem('/upp', '', '', '');
Menu[26] = new MenuItem('/upp/searches/partner_search.perl', '', '', '');
Menu[27] = new MenuItem('/upp/searches/partner_details.perl', '', '', '');
Menu[28] = new MenuItem('/upp/searches/casino_search.perl', '', '', '');
Menu[29] = new MenuItem('/upp/finops/cashflow_details.perl', '', '', '');
Menu[30] = new MenuItem('/upp/finops/payment_batch.perl', '', '', '');
Menu[31] = new MenuItem('/upp/finops/view_payments.perl', '', '', '');
Menu[32] = new MenuItem('/upp/finops/sales_perf.perl', '', '', '');
Menu[33] = new MenuItem('/campaign/test_partner_tpl.perl', '', '', '');
Menu[34] = new MenuItem('/manager', '', '', '');
Menu[35] = new MenuItem('/user-manage?referer=javascript:window.close()', 'pwd_window', 'center=yes,resizable=yes,width=600,height=700,toolbar=yes,scrollbars=yes', '');
Menu[36] = new MenuItem('/manager/game_tx_monitor.perl', '', '', '');
Menu[37] = new MenuItem('/manager/House%20Profits%20per%20Game%20%28NOT%20IMPLEMENTED%29', '', '', '');
Menu[38] = new MenuItem('/campaign/campaign_admin.perl', '', '', '');
Menu[39] = new MenuItem('/campaign/promo_admin.perl', '', '', '');
Menu[40] = new MenuItem('/campaign/coupon_admin.perl', '', '', '');
Menu[41] = new MenuItem('/campaign/segment_admin.perl', '', '', '');
Menu[42] = new MenuItem('/campaign/test_player_tpl.perl', '', '', '');
Menu[43] = new MenuItem('/searches', '', '', '');
Menu[44] = new MenuItem('/searches/customer_search.perl', '', '', '');
Menu[45] = new MenuItem('/searches/client_search.perl', '', '', '');
Menu[46] = new MenuItem('/searches/cc_search.perl', '', '', '');
Menu[47] = new MenuItem('/searches/op_search.perl', '', '', '');
Menu[48] = new MenuItem('/searches/wg_event_search.perl', '', '', '');
Menu[49] = new MenuItem('/searches/mpg_search.perl', '', '', '');
Menu[50] = new MenuItem('/searches/mpg_reports.perl', '', '', '');
Menu[51] = new MenuItem('/searches/mp_tourney.perl', '', '', '');
Menu[52] = new MenuItem('/searches/req_log_search.perl', '', '', '');
Menu[53] = new MenuItem('/services', '', '', '');
Menu[54] = new MenuItem('http://rtdev2.grandvirtual.com', 'RT', '', '');
Menu[55] = new MenuItem('http://fidel.grandvirtual.com:8005/cgi-bin/pva.cgi', 'PVA', '', '');
Menu[56] = new MenuItem('/services/Mailing%20List%20Admin%20%28NOT%20IMPLEMENTED%29', '', '', '');
Menu[57] = new MenuItem('/services/Personal%20Messaging%20%28NOT%20IMPLEMENTED%29', '', '', '');
Menu[58] = new MenuItem('http://gv.grandvirtual.com/cgi-bin/geolocate', 'GEO', '', '');
Menu[59] = new MenuItem('/finops', '', '', '');
Menu[60] = new MenuItem('/finops/new_batch.perl', '', '', '');
Menu[61] = new MenuItem('/finops/postproc.perl', '', '', '');
Menu[62] = new MenuItem('/finops/ban_purchase_methods.perl', '', '', '');
Menu[63] = new MenuItem('/finops/choose_cheque_batch.perl', '', '', '');
Menu[64] = new MenuItem('/finops/choose_otherpay_batch.perl', '', '', '');
Menu[65] = new MenuItem('/finops/profit.perl', '', '', '');
Menu[66] = new MenuItem('/finops/chargeback.perl', '', '', '');
Menu[67] = new MenuItem('/finops/rtm_volume.perl', '', '', '');
Menu[68] = new MenuItem('/upp', '', '', '');
Menu[69] = new MenuItem('/upp/searches/partner_search.perl', '', '', '');
Menu[70] = new MenuItem('/upp/searches/partner_details.perl', '', '', '');
Menu[71] = new MenuItem('/upp/searches/casino_search.perl', '', '', '');
Menu[72] = new MenuItem('/upp/finops/cashflow_details.perl', '', '', '');
Menu[73] = new MenuItem('/upp/finops/payment_batch.perl', '', '', '');
Menu[74] = new MenuItem('/upp/finops/view_payments.perl', '', '', '');
Menu[75] = new MenuItem('/upp/finops/sales_perf.perl', '', '', '');
Menu[76] = new MenuItem('/campaign/test_partner_tpl.perl', '', '', '');
Menu[77] = new MenuItem('/manager', '', '', '');
Menu[78] = new MenuItem('/user-manage?referer=javascript:window.close()', 'pwd_window', 'center=yes,resizable=yes,width=600,height=700,toolbar=yes,scrollbars=yes', '');
Menu[79] = new MenuItem('/manager/game_tx_monitor.perl', '', '', '');
Menu[80] = new MenuItem('/manager/House%20Profits%20per%20Game%20%28NOT%20IMPLEMENTED%29', '', '', '');
Menu[81] = new MenuItem('/campaign/campaign_admin.perl', '', '', '');
Menu[82] = new MenuItem('/campaign/promo_admin.perl', '', '', '');
Menu[83] = new MenuItem('/campaign/coupon_admin.perl', '', '', '');
Menu[84] = new MenuItem('/campaign/segment_admin.perl', '', '', '');
Menu[85] = new MenuItem('/campaign/test_player_tpl.perl', '', '', '');
