require "$form->{path}/js.pl";

use SL::CM;

1;

sub fmt_amount {
  my ($value) = @_;
  return $form->format_amount(\%myconfig, $value, ($form->{precision} || 2));
}

sub payment_accounts {
  my $dbh = $form->dbconnect(\%myconfig);
  my $query = qq|
    SELECT accno, description FROM chart
    WHERE charttype = 'A' AND accno LIKE '10%'
    ORDER BY accno|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  my @account;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @account, "$ref->{accno}--$ref->{description}";
  }
  $sth->finish;
  $dbh->disconnect;

  $form->{selectaccount} = join "\n", @account;
  $form->{payment_accno} = '1065--Kas Kecil'
    unless defined $form->{payment_accno} && $form->{payment_accno} ne '';
  $form->{payment_accno} = $account[0]
    unless grep { $_ eq $form->{payment_accno} } @account;
}

sub report {

  $form->{title} = $locale->text('Payment Commission');
  $form->{nextsub} = 'list';
  $form->{datepaid} ||= '';

  CM->employees(\%myconfig, $form);
  $form->{selectemployee} = "\n";
  for (@{ $form->{CM_employees} }) {
    $form->{selectemployee} .= qq|$_->{name}--$_->{id}\n|;
  }
  chomp $form->{selectemployee};
  $form->{selectemployee} = $form->escape($form->{selectemployee}, 1);

  &payment_accounts;

  $form->{showpaid} = ($form->{showpaid} || '') eq 'Y' ? 'checked' : '';

  my $employee_select = $form->select_option($form->{selectemployee}, $form->{employee_id}, 1);
  my $account_select = $form->select_option($form->{selectaccount}, $form->{payment_accno}, 1);
  my $calendar = &js_calendar("main", "datepaid");
  my $hidden = $form->hide_form(qw(nextsub path login));
  my $source_val = $form->quote($form->{source} || '');
  my $memo_val = $form->quote($form->{memo} || '');

  my $salesperson = $locale->text('Salesperson');
  my $date = $locale->text('Date');
  my $account = $locale->text('Account');
  my $source = $locale->text('Source');
  my $memo = $locale->text('Memo');
  my $showpaid_label = $locale->text('Show Paid');
  my $continue = $locale->text('Continue');

  $form->header;
  &calendar;

  print <<"HTML";
<body>

<form method="post" name="main" action="$form->{script}">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right nowrap>$salesperson</th>
          <td><select name=employee_id>$employee_select</select></td>
        </tr>
        <tr>
          <th align=right nowrap>$date</th>
          <td nowrap><input name=datepaid size=11 class=date title="$myconfig{dateformat}" value="$form->{datepaid}">$calendar</td>
        </tr>
        <tr>
          <th align=right nowrap>$account</th>
          <td><select name=payment_accno>$account_select</select></td>
        </tr>
        <tr>
          <th align=right nowrap>$source</th>
          <td><input name=source size=30 value="$source_val"></td>
        </tr>
        <tr>
          <th align=right nowrap>$memo</th>
          <td><input name=memo size=40 value="$memo_val"></td>
        </tr>
        <tr>
          <td></td>
          <td><input name=showpaid class=checkbox type=checkbox value=Y $form->{showpaid}> $showpaid_label</td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<br>
<input type=submit class=submit name=action value="$continue">
$hidden
</form>
HTML

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|</body>\n</html>\n|;
}

sub list {

  CM->outstanding(\%myconfig, $form);

  $form->{title} = $locale->text('Payment Commission');
  $form->{nextsub} = 'post';

  my $header = qq|
<table width=100%>
  <tr class=listheading>
    <th>&nbsp;</th>
    <th>|.$locale->text('Invoice').qq|</th>
    <th>|.$locale->text('Salesperson').qq|</th>
    <th>|.$locale->text('Commission Date').qq|</th>
    <th align=right>|.$locale->text('Gross').qq|</th>
    <th align=right>|.$locale->text('Deduction').qq|</th>
    <th align=right>|.$locale->text('Net').qq|</th>
    <th align=right>|.$locale->text('Paid').qq|</th>
    <th align=right>|.$locale->text('Due').qq|</th>
    <th align=right>|.$locale->text('Pay').qq|</th>
  </tr>
|;

  my $rows = '';
  my $total_due = 0;
  my $i = 0;

  for my $ref (@{ $form->{CM_outstanding} }) {
    $i++;
    $total_due += $ref->{due};
    $form->{"id_$i"} = $ref->{id};
    my $class = 'listrow'.($i % 2);
    my $due = &fmt_amount($ref->{due});
    my $id_field = $form->hide_form("id_$i");

    $rows .= qq|
  <tr class=$class>
    <td align=center><input name="ndx_$i" type=checkbox class=checkbox value=1 checked>$id_field</td>
    <td>$ref->{invnumber}&nbsp;</td>
    <td>$ref->{employee}&nbsp;</td>
    <td>$ref->{transdate}&nbsp;</td>
    <td align=right>|.&fmt_amount($ref->{gross}).qq|&nbsp;</td>
    <td align=right>|.&fmt_amount($ref->{deduction}).qq|&nbsp;</td>
    <td align=right>|.&fmt_amount($ref->{net}).qq|&nbsp;</td>
    <td align=right>|.&fmt_amount($ref->{paid}).qq|&nbsp;</td>
    <td align=right>$due&nbsp;</td>
    <td align=right><input name="paid_$i" class=inputright size=11 value="$due"></td>
  </tr>
|;
  }

  $form->{rowcount} = $i;
  my $hidden = $form->hide_form(qw(nextsub path login employee_id datepaid payment_accno source memo showpaid rowcount));

  $form->header;

  print qq|
<body>

<form method="post" name="main" action="$form->{script}">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
</table>
|;

  print $header;
  print $rows;

  print qq|
  <tr class=listtotal>
    <th colspan=8 align=right>|.$locale->text('Total Due').qq|&nbsp;</th>
    <th align=right>|.&fmt_amount($total_due).qq|</th>
    <th>&nbsp;</th>
  </tr>
</table>

<p>|.$locale->text('Date').qq|: $form->{datepaid} &nbsp; |.$locale->text('Account').qq|: $form->{payment_accno}</p>

<br>
<hr size=3 noshade>

<input type=submit class=submit name=action value="|.$locale->text('Post Payment').qq|">
<input type=submit class=submit name=action value="|.$locale->text('Back').qq|">
$hidden
</form>

</body>
</html>
|;
}

sub post {

  my ($ok, $glid, $message) = CM->pay(\%myconfig, $form);

  $form->error($message) unless $ok;

  $form->{callback} = "$form->{script}?action=report&login=$form->{login}&path=$form->{path}";
  $form->redirect($locale->text('Commission payment posted!'));
}

sub back {
  &report;
}

sub continue { &{$form->{nextsub}} };

# Locale files do not exist for this custom script yet, so keep the
# capitalised action names working as well.
sub Continue { &list }
sub Back { &report }
sub post_payment { &post }
