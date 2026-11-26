require "$form->{path}/arap.pl";

use SL::CM;

1;

sub report {

  $form->{title} = $locale->text('Sales Commission');
  $form->{nextsub} = 'generate';

  CM->employees(\%myconfig, $form);
  $form->{commission_deduction} = CM->setting(\%myconfig, $form);

  $form->{selectemployee} = "\n";
  for (@{ $form->{CM_employees} }) {
    $form->{selectemployee} .= qq|$_->{name}--$_->{id}\n|;
  }
  chomp $form->{selectemployee};
  $form->{selectemployee} = $form->escape($form->{selectemployee}, 1);

  $form->header;

  &calendar;

  print qq|
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
          <th align=right nowrap>|.$locale->text('Salesperson').qq|</th>
          <td><select name=employee_id>|
          .$form->select_option($form->{selectemployee}, $form->{employee_id}, 1)
          .qq|</select></td>
        </tr>
        <tr>
          <th align=right nowrap>|.$locale->text('From').qq|</th>
          <td colspan=3 nowrap><input name=fromdate size=11 class=date title="$myconfig{dateformat}" value="$form->{fromdate}">|.&js_calendar("main", "fromdate").qq| <b>|.$locale->text('To').qq|</b> <input name=todate size=11 class=date title="$myconfig{dateformat}" value="$form->{todate}">|.&js_calendar("main", "todate").qq|</td>
        </tr>
        <tr>
          <th align=right nowrap>|.$locale->text('Deduction').qq| (%)</th>
          <td><input name=commission_deduction size=5 value="$form->{commission_deduction}"></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Generate').qq|">
|;

  $form->hide_form(qw(nextsub path login));

  print qq|
</form>
|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
</body>
</html>
|;

}


sub generate {

  $form->{title} = $locale->text('Sales Commission');
  $form->{commission_deduction} = CM->save_setting(\%myconfig, $form);

  my $posted = CM->post_pending(\%myconfig, $form);
  CM->report(\%myconfig, $form);

  $form->{nextsub} = 'print';

  $form->header;

  print qq|
<body>
|;

  &render_report(0);

  print qq|
<p>|.$locale->text('Posted').qq|: $posted</p>

<form method="post" name="main" action="$form->{script}">
|;

  $form->hide_form(qw(nextsub path login title fromdate todate commission_deduction employee_id));

  my %button = ('Print' => { ndx => 1, key => 'P', value => $locale->text('Print Report') });
  $form->print_button(\%button);

  print qq|
</form>

</body>
</html>
|;

}


sub print_report { &print }

sub print {

  $form->{title} = $locale->text('Sales Commission');
  CM->report(\%myconfig, $form);

  $form->header;

  print qq|
<body>
|;

  print qq|
<div align=right>
  <input type=button class=submit value="|.$locale->text('Print').qq|" onclick="window.print()">
</div>
|;

  &render_report(1);

  print qq|
</body>
</html>
|;

}


sub render_report {
  my ($printable) = @_;

  my $precision = $form->{precision} || 2;

  my $amount = sub {
    my ($value) = @_;
    return $form->format_amount(\%myconfig, $value, $precision, '&nbsp;');
  };

  my $caption = join ' &nbsp; ', grep { $_ ne '' } (
    ($form->{fromdate} || $form->{todate})
      ? $form->{fromdate}.' - '.$form->{todate} : '',
    ($form->{employee_id} || '') =~ /^(.*)--/ ? $1 : '',
  );

  if ($printable) {
    print qq|
<table width=100%>
  <tr>
    <th align=left>$myconfig{company}</th>
    <th align=right>$locale->text('Sales Commission')</th>
  </tr>
</table>
|;
  }

  print qq|
<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
</table>
|;

  print qq|<p>$caption</p>| if $caption;

  print qq|
<table width=100%>
  <tr class=listheading>
    <th>|.$locale->text('Salesperson').qq|</th>
    <th>|.$locale->text('Rate').qq|</th>
    <th>|.$locale->text('Invoices').qq|</th>
    <th>|.$locale->text('Gross').qq|</th>
    <th>|.$locale->text('Deduction').qq|</th>
    <th>|.$locale->text('Net').qq|</th>
  </tr>
|;

  my $gross = 0;
  my $cut = 0;
  my $net = 0;
  my $j = 0;

  for my $ref (@{ $form->{CM_summary} }) {
    $gross += $ref->{gross};
    $cut += $ref->{deduction};
    $net += $ref->{net};
    $j++; $j %= 2;

    print qq|
  <tr class=listrow$j>
    <td>|.$form->quote($ref->{name}).qq|&nbsp;</td>
    <td align=right>|.$amount->($ref->{rate}).qq|</td>
    <td align=right>$ref->{invoices}</td>
    <td align=right>|.$amount->($ref->{gross}).qq|</td>
    <td align=right>|.$amount->($ref->{deduction}).qq|</td>
    <td align=right>|.$amount->($ref->{net}).qq|</td>
  </tr>
|;
  }

  print qq|
  <tr class=listtotal>
    <th>|.$locale->text('Total').qq|</th>
    <th>&nbsp;</th>
    <th>&nbsp;</th>
    <th align=right>|.$amount->($gross).qq|</th>
    <th align=right>|.$amount->($cut).qq|</th>
    <th align=right>|.$amount->($net).qq|</th>
  </tr>
</table>

<p></p>

<table width=100%>
  <tr class=listheading>
    <th>|.$locale->text('Salesperson').qq|</th>
    <th>|.$locale->text('Customer').qq|</th>
    <th>|.$locale->text('Invoice').qq|</th>
    <th>|.$locale->text('Period').qq|</th>
    <th>|.$locale->text('Transaction Date').qq|</th>
    <th>|.$locale->text('Paid Date').qq|</th>
    <th>|.$locale->text('Gross').qq|</th>
    <th>|.$locale->text('Deduction').qq|</th>
    <th>|.$locale->text('Net').qq|</th>
  </tr>
|;

  $j = 0;
  for my $ref (@{ $form->{CM_detail} }) {
    $j++; $j %= 2;

    print qq|
  <tr class=listrow$j>
    <td>|.$form->quote($ref->{employee}).qq|&nbsp;</td>
    <td>|.$form->quote($ref->{customer}).qq|&nbsp;</td>
    <td>|.$form->quote($ref->{invnumber}).qq|&nbsp;</td>
    <td>|.$form->quote($ref->{period}).qq|&nbsp;</td>
    <td>$ref->{transdate}&nbsp;</td>
    <td>$ref->{datepaid}&nbsp;</td>
    <td align=right>|.$amount->($ref->{gross}).qq|</td>
    <td align=right>|.$amount->($ref->{gross} - $ref->{net}).qq|</td>
    <td align=right>|.$amount->($ref->{net}).qq|</td>
  </tr>
|;
  }

  print qq|
</table>
|;

  if ($printable) {
    print qq|
<br>
<table width=100%>
  <tr>
    <td width=50% align=center>
      <br><br>
      _______________________________<br>
      |.$locale->text('Penerima').qq|
    </td>
    <td width=50% align=center>
      <br><br>
      _______________________________<br>
      |.$locale->text('Approved').qq|
    </td>
  </tr>
</table>
|;
  }

}

sub continue { &{$form->{nextsub}} };
