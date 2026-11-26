require "$form->{path}/arap.pl";

use SL::CM;

1;

sub fmt_amount {
  my ($value, $nbsp) = @_;
  return $form->format_amount(\%myconfig, $value, ($form->{precision} || 2), ($nbsp ? '&nbsp;' : ''));
}

sub text_val {
  my ($value) = @_;
  $value = '' unless defined $value;

  if (($form->{format} || '') eq 'pdf') {
    $value =~ s/\\/\\\\/g;
    $value =~ s/([&%\$\#_{}])/\\$1/g;
  } else {
    $value =~ s/&/&amp;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
  }

  $value;
}

sub prepare_data {

  CM->report(\%myconfig, $form);

  for my $key (qw(cm_summary_name cm_summary_rate cm_summary_invoices
                  cm_summary_gross cm_summary_deduction cm_summary_net
                  cm_detail_customer cm_detail_invoice cm_detail_period
                  cm_detail_transdate cm_detail_paiddate cm_detail_gross
                  cm_detail_deduction cm_detail_net cm_detail_subtotal
                  cm_detail_row cm_detail_grand cm_detail_name)) {
    $form->{$key} = [];
  }

  my @caption = grep { $_ ne '' } (
    ($form->{fromdate} || $form->{todate})
      ? $form->{fromdate}.' - '.$form->{todate} : '',
    ($form->{employee_id} || '') =~ /^(.*)--/ ? $1 : '',
  );
  $form->{cm_caption} = join ' | ', map { text_val($_) } @caption;

  my ($total_gross, $total_deduction, $total_net) = (0, 0, 0);
  my $i = 0;

  for my $ref (@{ $form->{CM_summary} }) {
    $total_gross += $ref->{gross};
    $total_deduction += $ref->{deduction};
    $total_net += $ref->{net};

    $form->{cm_summary_name}[$i] = text_val($ref->{name});
    $form->{cm_summary_rate}[$i] = fmt_amount($ref->{rate});
    $form->{cm_summary_invoices}[$i] = $ref->{invoices};
    $form->{cm_summary_gross}[$i] = fmt_amount($ref->{gross});
    $form->{cm_summary_deduction}[$i] = fmt_amount($ref->{deduction});
    $form->{cm_summary_net}[$i] = fmt_amount($ref->{net});
    $i++;
  }

  $form->{cm_total_gross} = fmt_amount($total_gross);
  $form->{cm_total_deduction} = fmt_amount($total_deduction);
  $form->{cm_total_net} = fmt_amount($total_net);

  my $current = '';
  my %sub;
  my $d = 0;

  my $flush_subtotal = sub {
    return unless $sub{invoices};

    $form->{cm_detail_subtotal}[$d] = 1;
    $form->{cm_detail_row}[$d] = 0;
    $form->{cm_detail_grand}[$d] = 0;
    $form->{cm_detail_name}[$d] = text_val($current);
    $form->{cm_detail_invoice}[$d] = $sub{invoices};
    $form->{cm_detail_gross}[$d] = fmt_amount($sub{gross});
    $form->{cm_detail_deduction}[$d] = fmt_amount($sub{deduction});
    $form->{cm_detail_net}[$d] = fmt_amount($sub{net});
    $d++;
    %sub = ();
  };

  my ($all_gross, $all_deduction, $all_net, $all_invoices) = (0, 0, 0, 0);

  for my $ref (@{ $form->{CM_detail} }) {
    my $cut = $ref->{gross} - $ref->{net};

    if ($ref->{employee} ne $current) {
      &$flush_subtotal;
      $current = $ref->{employee};
    }

    $sub{invoices}++;
    $sub{gross} += $ref->{gross};
    $sub{deduction} += $cut;
    $sub{net} += $ref->{net};

    $all_invoices++;
    $all_gross += $ref->{gross};
    $all_deduction += $cut;
    $all_net += $ref->{net};

    $form->{cm_detail_subtotal}[$d] = 0;
    $form->{cm_detail_row}[$d] = 1;
    $form->{cm_detail_grand}[$d] = 0;
    $form->{cm_detail_customer}[$d] = text_val($ref->{customer});
    $form->{cm_detail_invoice}[$d] = text_val($ref->{invnumber});
    $form->{cm_detail_period}[$d] = text_val($ref->{period});
    $form->{cm_detail_transdate}[$d] = text_val($ref->{transdate});
    $form->{cm_detail_paiddate}[$d] = text_val($ref->{datepaid});
    $form->{cm_detail_gross}[$d] = fmt_amount($ref->{gross});
    $form->{cm_detail_deduction}[$d] = fmt_amount($cut);
    $form->{cm_detail_net}[$d] = fmt_amount($ref->{net});
    $d++;
  }

  &$flush_subtotal;

  $form->{cm_detail_subtotal}[$d] = 0;
  $form->{cm_detail_row}[$d] = 0;
  $form->{cm_detail_grand}[$d] = 1;
  $form->{cm_detail_invoice}[$d] = $all_invoices;
  $form->{cm_detail_gross}[$d] = fmt_amount($all_gross);
  $form->{cm_detail_deduction}[$d] = fmt_amount($all_deduction);
  $form->{cm_detail_net}[$d] = fmt_amount($all_net);

}


sub report {

  $form->{title} = $locale->text('Sales Commission');
  $form->{nextsub} = 'generate';
  $form->{format} ||= $myconfig{outputformat} || 'html';

  CM->employees(\%myconfig, $form);
  $form->{commission_deduction} = CM->setting(\%myconfig, $form);

  $form->{selectemployee} = "\n";
  for (@{ $form->{CM_employees} }) {
    $form->{selectemployee} .= qq|$_->{name}--$_->{id}\n|;
  }
  chomp $form->{selectemployee};
  $form->{selectemployee} = $form->escape($form->{selectemployee}, 1);

  my $formats = qq|<option value="html">HTML<option value="pdf">PDF|;
  $formats =~ s/(<option value="\Q$form->{format}\E")/$1 selected/;
  $formats = qq|<option value="html">HTML| unless $latex;

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
        <tr>
          <th align=right nowrap>|.$locale->text('Format').qq|</th>
          <td><select name=format>$formats</select></td>
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
  $form->{format} = 'html' unless $form->{format} =~ /^(html|pdf)$/;

  $form->{commission_deduction} = CM->save_setting(\%myconfig, $form);

  my $posted = CM->post_pending(\%myconfig, $form);
  &prepare_data;

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

  $form->hide_form(qw(nextsub path login title fromdate todate commission_deduction employee_id format));

  my %button = ('Print' => { ndx => 1, key => 'P', value => $locale->text('Print Report') });
  $form->print_button(\%button);

  print qq|
</form>

</body>
</html>
|;

}


sub render_report {
  my ($printable) = @_;

  if ($printable) {
    print qq|
<table width=100%>
  <tr>
    <th align=left>$myconfig{company}</th>
    <th align=right>|.$locale->text('Sales Commission').qq|</th>
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

  print qq|<p>$form->{cm_caption}</p>| if $form->{cm_caption};

  print qq|
<table width=100%>
  <tr class=listheading>
    <th>|.$locale->text('Salesperson').qq|</th>
    <th align=right>|.$locale->text('Rate').qq|</th>
    <th align=right>|.$locale->text('Invoices').qq|</th>
    <th align=right>|.$locale->text('Gross').qq|</th>
    <th align=right>|.$locale->text('Deduction').qq|</th>
    <th align=right>|.$locale->text('Net').qq|</th>
  </tr>
|;

  for my $i (0 .. $#{ $form->{cm_summary_name} }) {
    print qq|
  <tr class=listrow@{[ $i % 2 ]}>
    <td>$form->{cm_summary_name}[$i]&nbsp;</td>
    <td align=right>$form->{cm_summary_rate}[$i]</td>
    <td align=right>$form->{cm_summary_invoices}[$i]</td>
    <td align=right>$form->{cm_summary_gross}[$i]</td>
    <td align=right>$form->{cm_summary_deduction}[$i]</td>
    <td align=right>$form->{cm_summary_net}[$i]</td>
  </tr>
|;
  }

  print qq|
  <tr class=listtotal>
    <th>|.$locale->text('Total').qq|</th>
    <th>&nbsp;</th>
    <th>&nbsp;</th>
    <th align=right>$form->{cm_total_gross}</th>
    <th align=right>$form->{cm_total_deduction}</th>
    <th align=right>$form->{cm_total_net}</th>
  </tr>
</table>

<p></p>

<table width=100%>
  <tr class=listheading>
    <th>|.$locale->text('Customer').qq|</th>
    <th>|.$locale->text('Invoice').qq|</th>
    <th>|.$locale->text('Period').qq|</th>
    <th>|.$locale->text('Transaction Date').qq|</th>
    <th>|.$locale->text('Paid Date').qq|</th>
    <th align=right>|.$locale->text('Gross').qq|</th>
    <th align=right>|.$locale->text('Deduction').qq|</th>
    <th align=right>|.$locale->text('Net').qq|</th>
  </tr>
|;

  for my $i (0 .. $#{ $form->{cm_detail_customer} }) {
    my $class = $form->{cm_detail_grand}[$i] ? 'listtotal'
              : $form->{cm_detail_subtotal}[$i] ? 'listsubtotal'
              : 'listrow'.($i % 2);

    if ($form->{cm_detail_subtotal}[$i] || $form->{cm_detail_grand}[$i]) {
      my $label = $form->{cm_detail_grand}[$i]
        ? $locale->text('Total') : $locale->text('Subtotal').' '.$form->{cm_detail_name}[$i];

      print qq|
  <tr class=$class>
    <th colspan=5 align=right>$label&nbsp;</th>
    <th align=right>$form->{cm_detail_gross}[$i]</th>
    <th align=right>$form->{cm_detail_deduction}[$i]</th>
    <th align=right>$form->{cm_detail_net}[$i]</th>
  </tr>
|;
    } else {
      print qq|
  <tr class=$class>
    <td>$form->{cm_detail_customer}[$i]&nbsp;</td>
    <td>$form->{cm_detail_invoice}[$i]&nbsp;</td>
    <td>$form->{cm_detail_period}[$i]&nbsp;</td>
    <td>$form->{cm_detail_transdate}[$i]&nbsp;</td>
    <td>$form->{cm_detail_paiddate}[$i]&nbsp;</td>
    <td align=right>$form->{cm_detail_gross}[$i]</td>
    <td align=right>$form->{cm_detail_deduction}[$i]</td>
    <td align=right>$form->{cm_detail_net}[$i]</td>
  </tr>
|;
    }
  }

  print qq|
</table>
|;

}


sub print_report { &print }

sub print {

  $form->{title} = $locale->text('Sales Commission');

  if (!$latex && $form->{format} eq 'pdf') {
    $form->{format} = 'html';
  }
  $form->{format} = 'html' unless $form->{format} =~ /^(html|pdf)$/;
  $form->{language_code} = '' unless defined $form->{language_code};

  &prepare_data;

  my $dbh = $form->dbconnect(\%myconfig);
  my %defaults = $form->get_defaults($dbh, [qw(company address tel fax companyemail companywebsite)]);
  $dbh->disconnect;
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  $form->{templates} = "$templates/$myconfig{templates}";
  $form->{IN} = ($form->{format} eq 'pdf') ? 'sales_commission.tex' : 'sales_commission.html';
  $form->{media} = 'screen';
  $form->{copies} = 1;

  $form->format_string(qw(company address tel fax companyemail companywebsite templates language_code));
  $form->parse_template(\%myconfig, $userspath, $dvipdf, $xelatex);

}

sub continue { &{$form->{nextsub}} };
