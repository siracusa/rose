<!-- start /admin/coupon/form/search.mc -->
<%perl>
$m->comp('/admin/table_editor/form/search.mc', %ARGS, 
         rows => 
         [
           [ 'code', 'start_date' ],
           [ 'coupon_id', 'end_date' ],
           [ 'sort',  [ 'per_page', 'list_button' ] ],
         ]);
</%perl>
<!-- end /admin/coupon/form/search.mc -->