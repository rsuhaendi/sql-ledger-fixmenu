require "$form->{path}/js.pl";

use SL::CM;

1;

sub fmt_amount {
  my ($value) = @_;
  return $form->format_amount(\%myconfig, $value, ($form->{precision} || 2));
}

sub setup {

  my $dbh = $form->dbconnect(\%myconfig);

  CM->employees(\%myconfig, $form);
  my @employee = @{ $form->{CM_employees} || [] };
  $form->{selectemployee} = $locale->text('All')."--0\n"
    . join "\n", map { "$_->{name}--$_->{id}" } @employee;

  if (!defined $form->{employee_id}) {
    $form->{employee_id} = @employee ? "$employee[0]{name}--$employee[0]{id}" : '';
  }

  my ($employee_id) = split /--/, ($form->{employee_id} || '');
  $employee_id *= 1;

  if ($employee_id) {
    my ($number) = $dbh->selectrow_array(qq|SELECT employeenumber FROM employee WHERE id = $employee_id|);
    $form->{employeenumber} = $number || '';

    my $query = qq|SELECT address1, address2, city, state, zipcode, country
                   FROM address WHERE trans_id = $employee_id ORDER BY id LIMIT 1|;
    my $sth = $dbh->prepare($query) || $form->dberror($query);
    $sth->execute;
    if (my $a = $sth->fetchrow_hashref(NAME_lc)) {
      for (qw(address1 address2 city state zipcode country)) { $form->{$_} = $a->{$_} || '' }
    }
    $sth->finish;
  } else {
    $form->{employeenumber} = '';
    for (qw(address1 address2 city state zipcode country)) { $form->{$_} = '' }
  }

  # Payment accounts, same source as Cash -> Payments (AP_paid accounts).
  my $query = qq|SELECT c.accno, c.description, l.description AS translation
                 FROM chart c
                 LEFT JOIN translation l
                   ON (l.trans_id = c.id AND l.language_code = '$myconfig{countrycode}')
                 WHERE c.link LIKE '%AP_paid%' AND c.closed = '0'
                 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  my @account;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    my $description = $ref->{translation} || $ref->{description};
    push @account, "$ref->{accno}--$description";
  }
  $sth->finish;

  $form->{selectaccount} = join "\n", @account;
  if (!$form->{payment_accno}) {
    $form->{payment_accno} = (grep { /^1065--/ } @account) ? '1065--Kas Kecil' : ($account[0] || '');
  }
  $form->{payment_accno} = $account[0]
    if $form->{payment_accno} && !grep { $_ eq $form->{payment_accno} } @account;

  # Payment method
  $query = qq|SELECT description, id FROM paymentmethod ORDER BY rn|;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  my @method;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @method, "$ref->{description}--$ref->{id}";
  }
  $sth->finish;
  $form->{selectpaymentmethod} = join "\n", @method;

  # Department
  $form->all_departments(\%myconfig, $dbh, 'vendor');
  my @department;
  for (@{ $form->{all_department} || [] }) {
    push @department, "$_->{description}--$_->{id}";
  }
  $form->{selectdepartment} = join "\n", @department;

  # Currency
  $form->{currencies} = $form->get_currencies(\%myconfig, $dbh);
  my @currency = split /:/, ($form->{currencies} || '');
  $form->{defaultcurrency} = $currency[0] || 'IDR';
  $form->{selectcurrency} = join "\n", @currency;
  $form->{currency} ||= $form->{defaultcurrency};

  $dbh->disconnect;

  for (qw(employee account paymentmethod department currency)) {
    $form->{"select$_"} = $form->escape($form->{"select$_"}, 1);
  }
}

sub report {

  $form->{title} = $locale->text('Payment Commission');
  $form->{payment} = 'commission';
  $form->{ARAP} = 'AP';
  $form->{vc} = 'vendor';

  $form->{datepaid} ||= $form->current_date(\%myconfig);
  $form->{employee_id} = '' if ($form->{all_sales} || '') eq 'Y';

  &setup;

  $form->{exchangerate} = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{datepaid});
  $form->{exchangerate} = 1 unless $form->{exchangerate} && $form->{exchangerate} > 0;
  $form->{oldcurrency} = $form->{currency};
  $form->{oldexchangerate} = $form->{exchangerate};
  $form->{olddatepaid} = $form->{datepaid};
  $form->{oldall_sales} = $form->{all_sales} || '';
  $form->{allbox} = 1 unless defined $form->{allbox};

  &update;
}

sub update {

  &setup unless $form->{selectemployee};

  my $reset = 0;
  $reset = 1 if ($form->{oldcurrency} || '') ne ($form->{currency} || '');
  $reset = 1 if ($form->{oldexchangerate} || '') ne ($form->{exchangerate} || '');
  $reset = 1 if ($form->{olddatepaid} || '') ne ($form->{datepaid} || '');
  $reset = 1 if ($form->{oldall_sales} || '') ne ($form->{all_sales} || '');

  my %old;
  unless ($reset) {
    for my $i (1 .. ($form->{rowcount} || 0)) {
      my $id = $form->{"id_$i"} || '';
      next unless $id =~ /^\d+$/;
      $old{$id} = {
        checked => $form->{"checked_$i"} ? 1 : 0,
        paid    => $form->{"paid_$i"},
      };
    }
  }

  CM->outstanding(\%myconfig, $form);

  my $rate = $form->parse_amount(\%myconfig, $form->{exchangerate});
  $rate = 1 unless $rate && $rate > 0;
  $form->{exchangerate_display} = $form->format_amount(\%myconfig, $rate);

  my $i = 0;
  my $checked = 0;
  my $total_due = 0;
  my $total_paid = 0;
  my @subtotal;

  for my $p (@{ $form->{CM_outstanding} || [] }) {
    $i++;

    my $id = $p->{id};
    my $base_amount = ($p->{net} || 0) * 1;
    my $base_paid   = ($p->{paid} || 0) * 1;
    my $base_due    = ($p->{due} || 0) * 1;

    my $amount = $form->format_amount(\%myconfig, $base_amount / $rate, ($form->{precision} || 2));
    my $due = $form->format_amount(\%myconfig, $base_due / $rate, ($form->{precision} || 2));
    my $paid_before = $form->format_amount(\%myconfig, $base_paid / $rate, ($form->{precision} || 2));

    my $is_checked = exists $old{$id} ? $old{$id}{checked} : ($form->{allbox} ? 1 : 0);
    my $paid = $due;
    if (exists $old{$id} && defined $old{$id}{paid} && $old{$id}{paid} ne '') {
      $paid = $old{$id}{paid};
    }

    $form->{"id_$i"} = $id;
    $form->{"employee_$i"} = $p->{employee};
    $form->{"invnumber_$i"} = $p->{invnumber};
    $form->{"transdate_$i"} = $p->{transdate};
    $form->{"duedate_$i"} = $p->{transdate};
    $form->{"gross_$i"} = $p->{gross};
    $form->{"deduction_$i"} = $p->{deduction};
    $form->{"net_$i"} = $p->{net};
    $form->{"amount_$i"} = $amount;
    $form->{"due_$i"} = $due;
    $form->{"paid_before_$i"} = $paid_before;
    $form->{"paid_$i"} = $paid;
    $form->{"checked_$i"} = $is_checked;
    $form->{"calcdiscount_$i"} = 0;

    $total_due += $base_due / $rate;

    my $employee = $p->{employee} || '';
    if (!@subtotal || $subtotal[-1]{employee} ne $employee) {
      push @subtotal, { employee => $employee, amount => 0 };
    }
    $subtotal[-1]{amount} += $base_due / $rate;

    if ($is_checked) {
      $checked++;
      $total_paid += $form->parse_amount(\%myconfig, $paid);
    }
  }

  $form->{CM_subtotal} = \@subtotal;
  $form->{total_due} = $form->format_amount(\%myconfig, $total_due, ($form->{precision} || 2));
  $form->{rowcount} = $i;
  $form->{allbox} = ($i && $checked == $i) ? 1 : 0;
  $form->{amount} = $form->format_amount(\%myconfig, $total_paid, ($form->{precision} || 2));
  $form->{oldamount} = $form->round_amount($total_paid, ($form->{precision} || 2));
  $form->{oldcurrency} = $form->{currency};
  $form->{oldexchangerate} = $form->{exchangerate};
  $form->{olddatepaid} = $form->{datepaid};
  $form->{oldall_sales} = $form->{all_sales} || '';

  &payment_header;
  &list_invoices;
  &payment_footer;
}

sub payment_header {

  $form->{title} = $locale->text('Payment Commission');

  my $employee_select = $form->select_option($form->{selectemployee}, $form->{employee_id}, 1);
  my $account_select = $form->select_option($form->{selectaccount}, $form->{payment_accno}, 1);
  my $method_select = $form->select_option($form->{selectpaymentmethod}, $form->{paymentmethod}, 1);
  my $department_select = $form->select_option($form->{selectdepartment}, $form->{department}, 1);
  my $currency_select = $form->select_option($form->{selectcurrency}, $form->{currency}, 1);

  my $method_row = '';
  if ($form->{selectpaymentmethod}) {
    my $label = $locale->text('Payment Method');
    $method_row = qq|
              <tr>
                <th align=right nowrap>$label</th>
                <td colspan=3><select name=paymentmethod onChange="javascript:document.main.submit()">$method_select</select></td>
              </tr>|;
  }

  my $department_row = '';
  if ($form->{selectdepartment}) {
    my $label = $locale->text('Department');
    $department_row = qq|
              <tr>
                <th align=right nowrap>$label</th>
                <td colspan=3><select name=department onChange="javascript:document.main.submit()">$department_select</select></td>
              </tr>|;
  }

  my $exchangerate = '';
  if ($form->{currency} ne $form->{defaultcurrency}) {
    my $label = $locale->text('Exchange Rate');
    $exchangerate = qq|
              <tr>
                <th align=right nowrap>$label</th>
                <td colspan=3><input name=exchangerate class=inputright size=11 value="$form->{exchangerate_display}"></td>
              </tr>|;
  }

  my $showpaid = ($form->{showpaid} || '') eq 'Y' ? 'checked' : '';
  my $allsales = ($form->{all_sales} || '') eq 'Y' ? 'checked' : '';

  my $all_label = $locale->text('All');
  my $salesperson = $locale->text('Salesperson');
  my $address = $locale->text('Address');
  my $memo = $locale->text('Memo');
  my $showpaid_label = $locale->text('Show Paid');
  my $payment = $locale->text('Payment');
  my $date_label = $locale->text('Date');
  my $currency_label = $locale->text('Currency');
  my $source_label = $locale->text('Source');
  my $amount_label = $locale->text('Amount');

  my $calendar = &js_calendar('main', 'datepaid');

  $form->header;
  &calendar;
  &check_all(qw(allbox checked_));

  print <<"HTML";
<body>

<form method="post" name="main" action="$form->{script}">
<input type=hidden name=action value=update>
HTML

  $form->hide_form(qw(nextsub path login title payment ARAP vc precision
                      defaultcurrency employee_id employeenumber payment_accno currency
                      exchangerate oldcurrency oldexchangerate olddatepaid
                      datepaid source memo oldall_sales rowcount));
  $form->hide_form(qw(selectemployee selectaccount selectpaymentmethod
                      selectdepartment selectcurrency));
  $form->hide_form(qw(address1 address2 city state zipcode country));

  print <<"HTML";
<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr valign=top>
          <td>
            <table>
              <tr>
                <th align=right nowrap>$salesperson</th>
                <td><select name=employee_id>$employee_select</select></td>
              </tr>
              <tr>
                <td align=right><input name=all_sales type=checkbox class=checkbox value=Y $allsales onChange="javascript:document.main.submit()"></td>
                <th align=left>$all_label</th>
              </tr>
              <tr>
                <th align=right nowrap>$address</th>
                <td colspan=2>
                  <table>
                    <tr><td>$form->{address1}</td></tr>
                    <tr><td>$form->{address2}</td></tr>
                    <tr><td>$form->{city}</td></tr>
                    <tr><td>$form->{state}</td></tr>
                    <tr><td>$form->{zipcode}</td></tr>
                    <tr><td>$form->{country}</td></tr>
                  </table>
                </td>
              </tr>
              <tr>
                <th align=right>$memo</th>
                <td colspan=2><input name=memo size=30 value="$form->{memo}"></td>
              </tr>
              <tr>
                <td></td>
                <td colspan=2><input name=showpaid type=checkbox class=checkbox value=Y $showpaid> $showpaid_label</td>
              </tr>
            </table>
          </td>
          <td align=right>
            <table>
              <tr>
                <th align=right nowrap>$payment</th>
                <td colspan=3><select name=payment_accno onChange="javascript:document.main.submit()">$account_select</select></td>
              </tr>
              $method_row
              $department_row
              <tr>
                <th align=right nowrap>$date_label</th>
                <td colspan=3><input name=datepaid value="$form->{datepaid}" title="$myconfig{dateformat}" size=11 class=date>$calendar</td>
              </tr>
              <tr>
                <th align=right nowrap>$currency_label</th>
                <td colspan=3><select name=currency onChange="javascript:document.main.submit()">$currency_select</select></td>
              </tr>
              $exchangerate
              <tr>
                <th align=right nowrap>$source_label</th>
                <td colspan=3><input name=source value="$form->{source}" size=11></td>
              </tr>
              <tr>
                <th align=right nowrap>$amount_label</th>
                <td colspan=3><input name=amount class=inputright size=11 value="$form->{amount}"></td>
                <input type=hidden name=oldamount value="$form->{oldamount}">
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
HTML

}

sub list_invoices {

  my @column_index = qw(checked employee invnumber transdate duedate amount due paid discount total);
  my $colspan = $#column_index + 1;

  my $invoice_label = $locale->text('Invoices');
  my %label = (
    checked   => '',
    employee  => $locale->text('Salesperson'),
    invnumber => $locale->text('Invoice'),
    transdate => $locale->text('Invoice Date'),
    duedate   => $locale->text('Due Date'),
    amount    => $locale->text('Amount'),
    due       => $locale->text('Due'),
    paid      => $locale->text('Paid'),
    discount  => $locale->text('Discount'),
    total     => $locale->text('Total'),
  );

  my $allbox = $form->{allbox} ? 'checked' : '';
  my $head = '';
  for (@column_index) {
    if ($_ eq 'checked') {
      $head .= qq|<th><input name=allbox type=checkbox class=checkbox value=1 $allbox onChange="CheckAll(); javascript:document.main.submit()"></th>|;
    } else {
      $head .= qq|<th>$label{$_}</th>|;
    }
    $head .= "\n";
  }

  my $total_for_label = $locale->text('Total for');
  my $total_label = $locale->text('Total');

  my $rows = '';
  my $j = 0;

  for my $i (1 .. ($form->{rowcount} || 0)) {
    my $id = $form->{"id_$i"} || '';
    my $employee = $form->{"employee_$i"} || '';
    my $checked = $form->{"checked_$i"} ? 'checked' : '';
    my $save_header = $form->{header};
    $form->{header} = 0;
    my $hidden = $form->hide_form(map { "${_}_$i" } qw(id employee invnumber transdate duedate gross deduction net amount due paid_before calcdiscount));
    $form->{header} = $save_header;

    $j++; $j %= 2;

    $rows .= qq|
        <tr class=listrow$j>
          <td align=center><input name="checked_$i" type=checkbox class=checkbox $checked onChange="javascript:document.main.submit()"></td>
          <td nowrap>$employee</td>
          <td>$form->{"invnumber_$i"}</td>
          <td nowrap>$form->{"transdate_$i"}</td>
          <td nowrap>$form->{"duedate_$i"}</td>
          <td align=right>$form->{"amount_$i"}</td>
          <td align=right>$form->{"due_$i"}</td>
          <td align=center><input name="paid_$i" class=inputright size=11 value="$form->{"paid_$i"}"></td>
          <td>&nbsp;</td>
          <td align=right>$form->{"paid_$i"}</td>
        </tr>
$hidden|;
  }

  # Subtotal per salesperson, then grand total.
  for my $subtotal (@{ $form->{CM_subtotal} || [] }) {
    my $employee = $subtotal->{employee} || '';
    my $amount = $form->format_amount(\%myconfig, $subtotal->{amount}, ($form->{precision} || 2));
    $rows .= qq|
        <tr class=listsubtotal>
          <td colspan=6 nowrap>$total_for_label $employee</td>
          <td align=right>$amount</td>
          <td colspan=3>&nbsp;</td>
        </tr>|;
  }

  print qq|
  <tr>
    <td>
      <table width=100%>
        <tr>
          <th class=listheading colspan=$colspan>$invoice_label</th>
        </tr>
        <tr>
$head
        </tr>
$rows
        <tr class=listtotal>
          <td colspan=6 align=right>$total_label</td>
          <td align=right>$form->{total_due}</td>
          <td colspan=3>&nbsp;</td>
        </tr>
      </table>
    </td>
  </tr>
|;

}

sub payment_footer {

  my %button = (
    'Update'       => { ndx => 1, key => 'U', value => $locale->text('Update') },
    'Select all'   => { ndx => 2, key => 'A', value => $locale->text('Select all') },
    'Deselect all' => { ndx => 3, key => 'A', value => $locale->text('Deselect all') },
    'Post'         => { ndx => 4, key => 'O', value => $locale->text('Post') },
    'Back'         => { ndx => 5, key => 'B', value => $locale->text('Back') },
  );

  if ($form->{allbox}) {
    delete $button{'Select all'};
  } else {
    delete $button{'Deselect all'};
  }

  $form->print_button(\%button);

  $form->hide_form(qw(helpref callback));

  print qq|
</form>

</body>
</html>
|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }
}

sub select_all {
  for my $i (1 .. ($form->{rowcount} || 0)) { $form->{"checked_$i"} = 1 }
  $form->{allbox} = 1;
  &update;
}

sub deselect_all {
  for my $i (1 .. ($form->{rowcount} || 0)) {
    $form->{"checked_$i"} = 0;
    $form->{"paid_$i"} = '';
  }
  $form->{allbox} = 0;
  &update;
}

sub post {

  my ($ok, $glid, $message) = CM->pay(\%myconfig, $form);
  $form->error($message) unless $ok;

  $form->{callback} = "$form->{script}?action=report&login=$form->{login}&path=$form->{path}";
  $form->redirect($locale->text('Commission payment posted!'));
}

sub back {
  $form->{rowcount} = 0;
  $form->{allbox} = 1;
  for my $i (1 .. ($form->{rowcount} || 0)) { $form->{"checked_$i"} = 0 }
  &report;
}

sub Continue { &report }
sub Update { &update }
sub Post { &post }
sub Back { &back }
*{'Select all'} = \&select_all;
*{'Deselect all'} = \&deselect_all;
sub post_payment { &post }
