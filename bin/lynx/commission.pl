require "$form->{path}/arap.pl";

use SL::CM;

1;

sub report {

  $form->{title} = $locale->text('Sales Commission');
  $form->{nextsub} = 'generate';

  $form->{commission_deduction} = CM->setting(\%myconfig, $form);

  $form->header;

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
          <th align=right nowrap>|.$locale->text('From').qq|</th>
          <td><input name=fromdate size=11 class=date title="$myconfig{dateformat}" value="$form->{fromdate}"></td>
        </tr>
        <tr>
          <th align=right nowrap>|.$locale->text('To').qq|</th>
          <td><input name=todate size=11 class=date title="$myconfig{dateformat}" value="$form->{todate}"></td>
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

  $form->{commission_deduction} = CM->save_setting(\%myconfig, $form);

  my $posted = CM->post_pending(\%myconfig, $form);
  CM->report(\%myconfig, $form);

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
</table>

<p>|.$locale->text('Posted').qq|: $posted</p>

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

  for my $ref (@{ $form->{CM_summary} }) {
    $gross += $ref->{gross};
    $cut += $ref->{deduction};
    $net += $ref->{net};

    print qq|
  <tr>
    <td>$ref->{name}&nbsp;</td>
    <td align=right>|.$form->format_amount(\%myconfig, $ref->{rate}, 2).qq|</td>
    <td align=right>$ref->{invoices}</td>
    <td align=right>|.$form->format_amount(\%myconfig, $ref->{gross}, 2).qq|</td>
    <td align=right>|.$form->format_amount(\%myconfig, $ref->{deduction}, 2).qq|</td>
    <td align=right>|.$form->format_amount(\%myconfig, $ref->{net}, 2).qq|</td>
  </tr>
|;
  }

  print qq|
  <tr class=listtotal>
    <th>|.$locale->text('Total').qq|</th>
    <th>&nbsp;</th>
    <th>&nbsp;</th>
    <th align=right>|.$form->format_amount(\%myconfig, $gross, 2).qq|</th>
    <th align=right>|.$form->format_amount(\%myconfig, $cut, 2).qq|</th>
    <th align=right>|.$form->format_amount(\%myconfig, $net, 2).qq|</th>
  </tr>
</table>

<p></p>

<table width=100%>
  <tr class=listheading>
    <th>|.$locale->text('Date').qq|</th>
    <th>|.$locale->text('Invoice').qq|</th>
    <th>|.$locale->text('Salesperson').qq|</th>
    <th>|.$locale->text('Gross').qq|</th>
    <th>|.$locale->text('Deduction').qq|</th>
    <th>|.$locale->text('Net').qq|</th>
  </tr>
|;

  for my $ref (@{ $form->{CM_detail} }) {
    print qq|
  <tr>
    <td>$ref->{datepaid}&nbsp;</td>
    <td>$ref->{invnumber}&nbsp;</td>
    <td>$ref->{name}&nbsp;</td>
    <td align=right>|.$form->format_amount(\%myconfig, $ref->{gross}, 2).qq|</td>
    <td align=right>|.$form->format_amount(\%myconfig, $ref->{gross} - $ref->{net}, 2).qq|</td>
    <td align=right>|.$form->format_amount(\%myconfig, $ref->{net}, 2).qq|</td>
  </tr>
|;
  }

  print qq|
</table>

</body>
</html>
|;

}

sub continue { &{$form->{nextsub}} };
