require "$form->{path}/arap.pl";

# arap.pl defines a Preview routine for invoices; override it for this report.
*preview = \&commission_preview;

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
                  cm_group_name cm_group_address cm_group_customercount
                  cm_group_paidcount cm_group_unpaidcount
                  cm_detail_customer cm_detail_invoice cm_detail_period
                  cm_detail_transdate cm_detail_paiddate cm_detail_status
                  cm_detail_gross cm_detail_deduction cm_detail_net
                  cm_detail_subtotal cm_detail_row cm_detail_grand
                  cm_detail_name)) {
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

  my $address = sub {
    my ($ref) = @_;
    my $value = join ', ', grep { $_ ne '' } (
      $ref->{address1}, $ref->{address2}, $ref->{city},
      $ref->{state}, $ref->{zipcode}, $ref->{country});
    return $value || '-';
  };

  my %groups;
  my @group_order;
  for my $ref (@{ $form->{CM_detail} }) {
    my $name = $ref->{employee} || '';
    unless ($groups{$name}) {
      $groups{$name} = {
        address => &$address($ref),
        customers => {},
        paid => 0,
        unpaid => 0,
      };
      push @group_order, $name;
    }
    my $customer = $ref->{customer_id} || $ref->{customer} || '';
    $groups{$name}{customers}{$customer} = 1 if $customer ne '';
    if (($ref->{paid_status} || '') eq 'Paid') {
      $groups{$name}{paid}++;
    } else {
      $groups{$name}{unpaid}++;
    }
  }

  my $gi = 0;
  for my $name (@group_order) {
    my $group = $groups{$name};
    $form->{cm_group_name}[$gi] = text_val($name);
    $form->{cm_group_address}[$gi] = text_val($group->{address});
    $form->{cm_group_customercount}[$gi] = scalar keys %{ $group->{customers} };
    $form->{cm_group_paidcount}[$gi] = $group->{paid};
    $form->{cm_group_unpaidcount}[$gi] = $group->{unpaid};
    $gi++;
  }

  my $current = '';
  my %sub;
  my $d = 0;

  my $flush_subtotal = sub {
    return unless $sub{rows};

    $form->{cm_detail_subtotal}[$d] = 1;
    $form->{cm_detail_row}[$d] = 0;
    $form->{cm_detail_grand}[$d] = 0;
    $form->{cm_detail_customer}[$d] = '';
    $form->{cm_detail_status}[$d] = '';
    $form->{cm_detail_name}[$d] = text_val($current);
    $form->{cm_detail_invoice}[$d] = $sub{paid};
    $form->{cm_detail_gross}[$d] = fmt_amount($sub{gross});
    $form->{cm_detail_deduction}[$d] = fmt_amount($sub{deduction});
    $form->{cm_detail_net}[$d] = fmt_amount($sub{net});
    $d++;
    %sub = ();
  };

  my ($all_gross, $all_deduction, $all_net, $all_invoices) = (0, 0, 0, 0);

  for my $ref (@{ $form->{CM_detail} }) {
    my $cut = $ref->{gross} - $ref->{net};
    my $paid = (($ref->{paid_status} || '') eq 'Paid') ? 1 : 0;

    if ($ref->{employee} ne $current) {
      &$flush_subtotal;
      $current = $ref->{employee};
    }

    $sub{rows}++;
    $sub{paid} += $paid;
    $sub{gross} += $ref->{gross};
    $sub{deduction} += $cut;
    $sub{net} += $ref->{net};

    $all_gross += $ref->{gross};
    $all_deduction += $cut;
    $all_net += $ref->{net};
    $all_invoices += $paid;

    $form->{cm_detail_subtotal}[$d] = 0;
    $form->{cm_detail_row}[$d] = 1;
    $form->{cm_detail_grand}[$d] = 0;
    $form->{cm_detail_customer}[$d] = text_val($ref->{customer});
    $form->{cm_detail_invoice}[$d] = text_val($ref->{invnumber});
    $form->{cm_detail_period}[$d] = text_val($ref->{period});
    $form->{cm_detail_transdate}[$d] = text_val($ref->{transdate});
    $form->{cm_detail_paiddate}[$d] = text_val($ref->{datepaid} || '-');
    $form->{cm_detail_status}[$d] = text_val($ref->{paid_status} || 'Unpaid');
    $form->{cm_detail_gross}[$d] = fmt_amount($ref->{gross});
    $form->{cm_detail_deduction}[$d] = fmt_amount($cut);
    $form->{cm_detail_net}[$d] = fmt_amount($ref->{net});
    $d++;
  }

  &$flush_subtotal;

  $form->{cm_detail_subtotal}[$d] = 0;
  $form->{cm_detail_row}[$d] = 0;
  $form->{cm_detail_grand}[$d] = 1;
  $form->{cm_detail_customer}[$d] = '';
  $form->{cm_detail_status}[$d] = '';
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

  $form->{format} ||= 'html';
  $form->{media} ||= 'screen';

  my $formats = qq|<option value="html">HTML<option value="pdf">PDF|;
  $formats =~ s/(<option value="\Q$form->{format}\E")/$1 selected/;
  $formats = qq|<option value="html">HTML| unless $latex;

  my $media = qq|<option value="screen">|.$locale->text('Screen')
            .qq|<option value="printer">|.$locale->text('Printer');
  $media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;

  print qq|
<table>
  <tr>
    <th align=left nowrap>|.$locale->text('Format').qq|</th>
    <td align=left><select name=format>$formats</select></td>
    <th align=left nowrap>|.$locale->text('Media').qq|</th>
    <td align=left><select name=media>$media</select></td>
  </tr>
</table>
|;

  $form->hide_form(qw(nextsub path login title fromdate todate commission_deduction employee_id));

  my %button = (
    'Preview' => { ndx => 1, key => 'V', value => $locale->text('Preview') },
    'Print'   => { ndx => 2, key => 'P', value => $locale->text('Print') },
    'Back'    => { ndx => 3, key => 'B', value => $locale->text('Back') },
  );
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

  for my $i (0 .. $#{ $form->{cm_group_name} }) {
    print qq|
<p>
  <b>|.$locale->text('Salesperson').qq|: $form->{cm_group_name}[$i]</b>
  &nbsp;|.$locale->text('Address').qq|: $form->{cm_group_address}[$i]
  &nbsp;|.$locale->text('Total Customer').qq|: $form->{cm_group_customercount}[$i]
  &nbsp;|.$locale->text('Total Invoice Paid').qq|: $form->{cm_group_paidcount}[$i]
  &nbsp;|.$locale->text('Total Invoice Unpaid').qq|: $form->{cm_group_unpaidcount}[$i]
</p>
|;
  }

  print qq|
<table width=100%>
  <tr class=listheading>
    <th>|.$locale->text('Customer').qq|</th>
    <th>|.$locale->text('Invoice').qq|</th>
    <th>|.$locale->text('Period').qq|</th>
    <th>|.$locale->text('Transaction Date').qq|</th>
    <th>|.$locale->text('Paid Date').qq|</th>
    <th>|.$locale->text('Status Paid').qq|</th>
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
        ? $locale->text('Total') : $locale->text('Subtotal');

      print qq|
  <tr class=$class>
    <th colspan=6 align=right>$label&nbsp;</th>
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
    <td>$form->{cm_detail_status}[$i]&nbsp;</td>
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

sub commission_preview {
  $form->{media} = 'screen';
  &print;
}

sub back {
  &report;
}

sub print {

  $form->{title} = $locale->text('Sales Commission');

  if (!$latex && $form->{format} eq 'pdf') {
    $form->{format} = 'html';
  }
  $form->{format} = 'html' unless $form->{format} =~ /^(html|pdf)$/;
  $form->{media} ||= 'screen';
  $form->{language_code} = '' unless defined $form->{language_code};

  &prepare_data;

  my $dbh = $form->dbconnect(\%myconfig);
  my %defaults = $form->get_defaults($dbh, [qw(company address tel fax companyemail companywebsite)]);
  my %printers = $form->get_defaults($dbh, ['printer_%']);
  $dbh->disconnect;
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
  for (keys %printers) {
    my ($label) = /^printer_(.*)$/;
    $form->{"${label}_printer"} = $printers{$_};
  }

  $form->{templates} = "$templates/$myconfig{templates}";
  $form->{IN} = ($form->{format} eq 'pdf') ? 'sales_commission.tex' : 'sales_commission.html';
  $form->{copies} = 1;
  $form->{bodyattr} = '';

  if ($form->{media} eq 'printer') {
    if ($form->{Printer_printer}) {
      $form->{OUT} = "| $form->{Printer_printer}";
    } else {
      $form->{bodyattr} = ' onload="window.print()"';
    }
  }

  $form->format_string(qw(company address tel fax companyemail companywebsite templates language_code));
  $form->parse_template(\%myconfig, $userspath, $dvipdf, $xelatex);

}

sub continue { &{$form->{nextsub}} };
