#=====================================================================
# Sales Commission backend
#======================================================================

package CM;

sub setting_db {
  my ($self, $dbh) = @_;

  my ($value) = $dbh->selectrow_array(qq|
    SELECT fldvalue FROM defaults WHERE fldname = 'commission_deduction'
  |);

  return (defined $value && $value =~ /^\d+(\.\d+)?$/ && $value >= 0 && $value <= 100)
    ? $value : 10;
}

sub employees {
  my ($self, $myconfig, $form) = @_;

  $form->{CM_employees} = [];

  my $dbh = $form->dbconnect($myconfig);
  my $sth = $dbh->prepare(qq|
    SELECT id, name FROM employee
    WHERE sales = '1' AND (enddate IS NULL OR enddate >= CURRENT_DATE)
    ORDER BY name
  |) || $form->dberror(qq|SELECT id, name FROM employee|);
  $sth->execute;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{CM_employees} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;
}

sub period {
  my ($self, $myconfig, $form, $date, $billing_type) = @_;

  return '' unless $date;

  my $iso = $date;
  $iso =~ s/\D//g;
  return '' unless $iso =~ /^\d{8}$/;

  my $start = $iso;
  my $end = $form->add_date($myconfig, $form->add_date($myconfig, $start, 1, 'month'), -1, 'day');

  if ($billing_type && $billing_type eq 'Pascabayar') {
    $start = $form->add_date($myconfig, $iso, -1, 'month');
    $end = $form->add_date($myconfig, $iso, -1, 'day');
  }

  for ($start, $end) { s/\D//g }

  return $form->format_date($myconfig->{dateformat}, $start)
    .' s/d '.$form->format_date($myconfig->{dateformat}, $end);
}

sub setting {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);
  my $value = $self->setting_db($dbh);
  $dbh->disconnect;

  $value;
}

sub save_setting {
  my ($self, $myconfig, $form) = @_;

  my $value = $form->{commission_deduction};
  $value = 10 unless defined $value && $value =~ /^\d+(\.\d+)?$/ && $value >= 0 && $value <= 100;

  my $dbh = $form->dbconnect($myconfig);
  $dbh->do(qq|UPDATE defaults SET fldvalue = '$value' WHERE fldname = 'commission_deduction'|);
  $dbh->do(qq|INSERT INTO defaults (fldname, fldvalue)
              SELECT 'commission_deduction', '$value'
              WHERE NOT EXISTS (SELECT 1 FROM defaults WHERE fldname = 'commission_deduction')|);
  $dbh->disconnect;

  $value;
}

sub post_invoice {
  my ($self, $myconfig, $dbh, $id) = @_;

  return 0 unless defined $id && $id =~ /^\d+$/;

  my $sth = $dbh->prepare(qq|
    SELECT a.id, a.invnumber, a.employee_id, a.amount, a.paid,
           a.datepaid, a.transdate, a.commission_posted,
           e.commission_amount
    FROM ar a
    LEFT JOIN employee e ON (e.id = a.employee_id)
    WHERE a.id = $id
  |) || return 0;
  $sth->execute || return 0;
  my $ref = $sth->fetchrow_hashref(NAME_lc);
  $sth->finish;

  return 0 unless $ref;
  return 0 if $ref->{commission_posted};
  return 0 if $ref->{paid} < $ref->{amount} - 0.005;
  return 0 unless $ref->{employee_id};

  my $gross = $ref->{commission_amount} * 1;
  return 0 unless $gross > 0;

  my $deduction = $self->setting_db($dbh);
  my $net = sprintf("%.2f", $gross * (1 - $deduction / 100));
  my $cut = sprintf("%.2f", $gross - $net);
  my $transdate = $ref->{datepaid} || $ref->{transdate};
  my $invnumber = $dbh->quote($ref->{invnumber} || 'Commission');

  $dbh->do(qq|UPDATE ar SET
                commission_amount = $gross,
                commission_deduction = $deduction,
                commission_net = $net,
                commission_posted = true
              WHERE id = $id|);

  $dbh->do(qq|INSERT INTO commission_payable
                (ar_id, invnumber, employee_id, gross, deduction, net, transdate, accrual_posted)
              SELECT $id, $invnumber, $ref->{employee_id}, $gross, $cut, $net, '$transdate', false
              WHERE NOT EXISTS (SELECT 1 FROM commission_payable WHERE ar_id = $id)|);

  1;
}

sub post_pending {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);

  my $sth = $dbh->prepare(qq|
    SELECT a.id
    FROM ar a
    JOIN employee e ON (e.id = a.employee_id)
    WHERE a.paid >= a.amount
      AND a.commission_posted = false
      AND e.commission_amount > 0
  |) || $form->dberror(qq|SELECT a.id FROM ar a|);
  $sth->execute;

  my @ids;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) { push @ids, $ref->{id} }
  $sth->finish;

  my $posted = 0;
  for my $id (@ids) { $posted++ if $self->post_invoice($myconfig, $dbh, $id) }

  $dbh->commit;
  $dbh->disconnect;

  $posted;
}

sub report {
  my ($self, $myconfig, $form) = @_;

  $form->{CM_summary} = [];
  $form->{CM_detail} = [];

  my $dbh = $form->dbconnect($myconfig);

  my @employee = split /--/, ($form->{employee_id} || '');
  my $employee_id = $employee[-1] || '';
  $employee_id *= 1;

  my $datefield = 'COALESCE(a.datepaid, a.transdate)';
  my $where = '';
  if ($form->{fromdate}) {
    $where .= " AND $datefield >= ".$dbh->quote($form->{fromdate});
  }
  if ($form->{todate}) {
    $where .= " AND $datefield <= ".$dbh->quote($form->{todate});
  }
  if ($employee_id) {
    $where .= " AND a.employee_id = $employee_id";
  }
  my $query = qq|
    SELECT e.id, e.name, e.commission_amount AS rate,
           count(*) AS invoices,
           sum(a.commission_amount) AS gross,
           sum(a.commission_amount - a.commission_net) AS deduction,
           sum(a.commission_net) AS net
    FROM ar a
    JOIN employee e ON (e.id = a.employee_id)
    WHERE a.invoice = true
      AND a.commission_posted = true
      AND a.paid >= a.amount
      $where
    GROUP BY e.id, e.name, e.commission_amount
    ORDER BY e.name
  |;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{CM_summary} }, $ref;
  }
  $sth->finish;

  $query = qq|
    SELECT a.datepaid, a.transdate, a.invnumber, e.name AS employee,
           ad.address1, ad.address2, ad.city, ad.state, ad.zipcode, ad.country,
           cu.id AS customer_id, cu.name AS customer, cu.billing_type,
           CASE WHEN a.paid >= a.amount THEN 'Paid' ELSE 'Unpaid' END AS paid_status,
           CASE WHEN a.commission_posted = true THEN a.commission_amount ELSE 0 END AS gross,
           CASE WHEN a.commission_posted = true THEN a.commission_deduction ELSE 0 END AS deduction,
           CASE WHEN a.commission_posted = true THEN a.commission_net ELSE 0 END AS net
    FROM ar a
    JOIN employee e ON (e.id = a.employee_id)
    LEFT JOIN address ad ON (ad.trans_id = e.id)
    LEFT JOIN customer cu ON (cu.id = a.customer_id)
    WHERE a.invoice = true
      $where
    ORDER BY e.name, $datefield, a.invnumber
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{period} = $self->period($myconfig, $form, $ref->{transdate}, $ref->{billing_type});
    for (qw(datepaid transdate)) {
      my $iso = $ref->{$_} || '';
      $iso =~ s/\D//g;
      $ref->{$_} = $iso =~ /^\d{8}$/
        ? $form->format_date($myconfig->{dateformat}, $iso) : '';
    }
    push @{ $form->{CM_detail} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;
}

sub _employee_id {
  my ($value) = @_;
  my @employee = split /--/, ($value || '');
  my $id = $employee[-1] || '';
  $id *= 1;
  return $id;
}

sub outstanding {
  my ($self, $myconfig, $form) = @_;

  $form->{CM_outstanding} = [];

  my $dbh = $form->dbconnect($myconfig);

  my $all_sales = ($form->{all_sales} || '') eq 'Y';
  my $employee_id = $all_sales ? 0 : _employee_id($form->{employee_id});
  my $where = '';
  $where .= " AND p.employee_id = $employee_id" if $employee_id;
  $where .= " AND p.paid < p.net - 0.005" unless $form->{showpaid};

  # Due Date filter, same workflow as Cash -> Payments/Receipts. Commission
  # rows use transdate as their due date.
  for my $field (qw(duedatefrom duedateto)) {
    my $iso = $form->datetonum($myconfig, $form->{$field} || '');
    next unless $iso =~ /^(\d{4})(\d{2})(\d{2})$/;
    my $date = "$1-$2-$3";
    $where .= $field eq 'duedatefrom'
      ? " AND p.transdate >= '$date'"
      : " AND p.transdate <= '$date'";
  }

  my $query = qq|
    SELECT p.*, e.name AS employee, e.employeenumber,
           cu.name AS customer,
           p.net - p.paid AS due
    FROM commission_payable p
    JOIN employee e ON (e.id = p.employee_id)
    LEFT JOIN ar a ON (a.id = p.ar_id)
    LEFT JOIN customer cu ON (cu.id = a.customer_id)
    WHERE 1=1 $where
    ORDER BY e.name, cu.name, p.transdate, p.invnumber|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    for (qw(transdate paid_date)) {
      my $iso = $ref->{$_} || '';
      $iso =~ s/\D//g;
      $ref->{$_} = $iso =~ /^\d{8}$/
        ? $form->format_date($myconfig->{dateformat}, $iso) : '';
    }
    push @{ $form->{CM_outstanding} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;
}

sub pay {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);
  $dbh->{RaiseError} = 1;
  $dbh->{PrintError} = 0;

  my $result = eval {
    my $employee_id = _employee_id($form->{employee_id});

    my ($accno) = split /--/, ($form->{payment_accno} || '');
    die $main::locale->text('Payment account missing!') unless $accno;

    my ($chart_id) = $dbh->selectrow_array(qq|
      SELECT id FROM chart WHERE accno = |.$dbh->quote($accno));
    die $main::locale->text('Payment account missing!') unless $chart_id;

    my $date = $form->{datepaid} || '';
    $date = $form->datetonum($myconfig, $date);
    my $date_sql = 'CURRENT_DATE';
    if ($date =~ /^(\d{4})(\d{2})(\d{2})$/) {
      $date_sql = qq|'$1-$2-$3'|;
    }

    my $rate = $form->parse_amount($myconfig, $form->{exchangerate});
    $rate = 1 unless $rate && $rate > 0;

    my @ids;
    my %pay;
    my %meta;
    my $rows = 0;

    for my $i (1 .. ($form->{rowcount} || 0)) {
      next unless $form->{"checked_$i"};
      my $id = $form->{"id_$i"} || 0;
      next unless $id =~ /^\d+$/;

      my $amount = $form->parse_amount($myconfig, $form->{"paid_$i"} || 0);
      next unless $amount > 0;

      $pay{$id} = $form->round_amount($amount * $rate, 2);
      $meta{$id} = {
        source => $form->{"source_$i"} || $form->{source} || 'Commission Payment',
        memo   => $form->{"memo_$i"} || $form->{memo} || 'Commission payment',
      };
      push @ids, $id;
      $rows++;
    }

    die $main::locale->text('Nothing to pay!') unless $rows;

    my $source = $dbh->quote($meta{$ids[0]}{source});
    my $memo = $dbh->quote($meta{$ids[0]}{memo});

    if (!$employee_id) {
      ($employee_id) = $dbh->selectrow_array(qq|
        SELECT employee_id FROM commission_payable WHERE id = $ids[0]|);
    }
    die $main::locale->text('Salesperson missing!') unless $employee_id;

    my $list = join ',', @ids;
    my $sth = $dbh->prepare(qq|
      SELECT * FROM commission_payable WHERE id IN ($list) FOR UPDATE|);
    $sth->execute;

    my %row;
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $row{$ref->{id}} = $ref;
    }
    $sth->finish;

    my ($total_paid, $total_gross, $total_net, $total_cut, $accruals) = (0, 0, 0, 0, 0);
    for my $id (@ids) {
      my $ref = $row{$id};
      die $main::locale->text('Commission not found!') unless $ref;

      my $due = $ref->{net} - $ref->{paid};
      my $tolerance = $rate * 0.01 + 0.005;
      if ($pay{$id} > $due) {
        die $main::locale->text('Payment exceeds outstanding commission!')
          if $pay{$id} > $due + $tolerance;
        $pay{$id} = $due;
      }

      $total_paid += $pay{$id};
      next if $ref->{accrual_posted};

      $total_gross += $ref->{gross};
      $total_net += $ref->{net};
      $total_cut += $ref->{deduction};
      $accruals++;
    }

    my $reference = $form->update_defaults($myconfig, 'glnumber', $dbh) || 'Commission Payment';
    my $reference_q = $dbh->quote($reference);

    my $glid = $dbh->selectrow_array(qq|
      INSERT INTO gl (reference, description, transdate, employee_id, notes, approved)
      VALUES ($reference_q, $source, $date_sql, $employee_id, $memo, 't')
      RETURNING id|);

    if ($accruals) {
      for my $entry (
          ['5480', -$total_gross],
          ['2290',  $total_net],
          ['4490',  $total_cut]) {
        my ($entry_accno, $amount) = @$entry;
        next unless $amount;

        $dbh->do(qq|
          INSERT INTO acc_trans
            (trans_id, chart_id, amount, transdate, source, memo, approved)
          VALUES ($glid, (SELECT id FROM chart WHERE accno = '$entry_accno'),
                  $amount, $date_sql, $source,
                  |.$dbh->quote('Commission accrual - '.$accruals.' invoice(s)').qq|, 't')|);
      }
    }

    if ($total_paid) {
      $dbh->do(qq|
        INSERT INTO acc_trans
          (trans_id, chart_id, amount, transdate, source, memo, approved)
        VALUES ($glid, (SELECT id FROM chart WHERE accno = '2290'),
                -$total_paid, $date_sql, $source, $memo, 't')|);

      my ($paymentid) = $dbh->selectrow_array(qq|SELECT nextval('id')|);
      $dbh->do(qq|
        INSERT INTO acc_trans
          (trans_id, chart_id, amount, transdate, source, memo, approved, id)
        VALUES ($glid, $chart_id, $total_paid, $date_sql, $source, $memo, 't', $paymentid)|);
      $dbh->do(qq|
        INSERT INTO payment (id, trans_id, exchangerate)
        VALUES ($paymentid, $glid, 1)|);

      for my $id (@ids) {
        $dbh->do(qq|
          UPDATE commission_payable SET
            paid = paid + $pay{$id},
            paid_date = $date_sql,
            payment_accno = |.$dbh->quote($accno).qq|,
            payment_source = |.$dbh->quote($meta{$id}{source}).qq|,
            payment_id = $paymentid,
            gl_id = $glid,
            accrual_posted = true
          WHERE id = $id|);
      }
    }

    $dbh->commit;
    return (1, $glid, $total_paid);
  };

  if ($@) {
    $dbh->rollback;
    my $error = $@ || $dbh->errstr || $main::locale->text('Payment failed!');
    $error =~ s/\s+at\s+\S+\s+line\s+\d+\.?\s*$//;
    return (0, $error);
  }

  $dbh->disconnect;
  return (1, undef, 0);
}

sub _fmt_date {
  my ($form, $myconfig, $date) = @_;
  return '' unless $date;

  my $iso = $date;
  $iso =~ s/\D//g;
  return $iso =~ /^\d{8}$/
    ? $form->format_date($myconfig->{dateformat}, $iso) : $date;
}

# Show commission liabilities in the standard AP Outstanding report without
# turning them into AP invoices.  Payment stays in Cash -> Payment Commission,
# so these rows are display-only in AP.
sub ap_outstanding {
  my ($self, $myconfig, $form, $dbh) = @_;

  return unless $form->{vc} eq 'vendor';

  my @where;

  my $employee_id = _employee_id($form->{employee});
  push @where, "p.employee_id = $employee_id" if $employee_id;

  if ($form->{vendor}) {
    my $name = $form->like(lc $form->{vendor});
    push @where, "lower(e.name) LIKE ".$dbh->quote($name);
  }

  if ($form->{invnumber}) {
    my $inv = $form->like(lc $form->{invnumber});
    push @where, "lower(p.invnumber) LIKE ".$dbh->quote($inv);
  }

  push @where, "p.transdate >= ".$dbh->quote($form->{transdatefrom}) if $form->{transdatefrom};
  push @where, "p.transdate <= ".$dbh->quote($form->{transdateto})   if $form->{transdateto};

  if ($form->{open} && !$form->{closed}) {
    push @where, "p.paid < p.net - 0.005";
  } elsif ($form->{closed} && !$form->{open}) {
    push @where, "p.paid >= p.net - 0.005";
  } elsif ($form->{outstanding}) {
    push @where, "p.paid < p.net - 0.005";
  }

  my $where = @where ? 'WHERE '.join(' AND ', @where) : '';

  my $query = qq|
    SELECT p.*, e.name AS employee
    FROM commission_payable p
    JOIN employee e ON (e.id = p.employee_id)
    $where
    ORDER BY p.transdate, p.invnumber|;

  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  while (my $p = $sth->fetchrow_hashref(NAME_lc)) {
    my $transdate = _fmt_date($form, $myconfig, $p->{transdate});
    my $datepaid  = _fmt_date($form, $myconfig, $p->{paid_date});
    my $amount    = $p->{net} * 1;
    my $paid      = $p->{paid} * 1;

    push @{ $form->{transactions} }, {
      id            => -$p->{id},
      commission    => 1,
      invnumber     => $p->{invnumber} || 'Commission',
      ordnumber     => '',
      transdate     => $transdate,
      duedate       => $transdate,
      datepaid      => $datepaid,
      amount        => $amount,
      paid          => $paid,
      netamount     => $amount,
      due           => $amount - $paid,
      tax           => 0,
      invoice       => 0,
      till          => '',
      employee      => $p->{employee},
      name          => $p->{employee},
      vendor_id     => 0,
      curr          => $form->{defaultcurrency} || 'IDR',
      exchangerate  => 1,
      notes         => 'Sales commission',
      description   => 'Sales commission',
      memo          => '',
      source        => $p->{payment_source} || '',
      accno         => $p->{payment_accno} || '2290',
      department    => '',
      ponumber      => '',
      shipvia       => '',
      waybill       => '',
      shippingpoint => '',
      warehouse     => '',
      paymentmethod => '',
      taxnumber     => '',
      paymentaccount=> '',
      projectnumber => '',
      address       => '',
      address1      => '',
      address2      => '',
      city          => '',
      zipcode       => '',
      country       => '',
      dcn           => '',
      paymentdiff   => 0,
      debit         => 0,
      credit        => 0,
      linetotal     => 0,
    };
  }

  $sth->finish;
}

sub ap_aging {
  my ($self, $myconfig, $form, $dbh) = @_;

  return unless $form->{vc} eq 'vendor' && $form->{arap} eq 'ap';

  my @where;
  my $employee_id = _employee_id($form->{employee});
  push @where, "p.employee_id = $employee_id" if $employee_id;

  if ($form->{vendor}) {
    my $name = $form->like(lc $form->{vendor});
    push @where, "lower(e.name) LIKE ".$dbh->quote($name);
  }

  push @where, "p.paid < p.net - 0.005";

  my $transdate = ($form->{overdue}) ? 'p.transdate' : 'p.transdate';
  push @where, "$transdate <= ".$dbh->quote($form->{todate}) if $form->{todate};

  my $where = @where ? 'WHERE '.join(' AND ', @where) : '';

  my $query = qq|
    SELECT p.*, e.name AS employee, e.employeenumber
    FROM commission_payable p
    JOIN employee e ON (e.id = p.employee_id)
    $where
    ORDER BY e.name, p.transdate, p.invnumber|;

  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  my @buckets = qw(c0 c15 c30 c45 c60 c75 c90);
  my %bound = (c0 => 0, c15 => 15, c30 => 30, c45 => 45, c60 => 60, c75 => 75, c90 => 90);
  my @active = grep { $form->{$_} } @buckets;
  @active = @buckets unless @active;

  my $curr = $form->{defaultcurrency} || 'IDR';
  my %sel_curr = map { $_ => 1 } split /:/, ($form->{currencies} || $curr);
  return unless $sel_curr{$curr};

  my $to = $form->{todate};
  $to =~ s/\D//g;
  $to = substr($to, 0, 8);

  my @add;
  while (my $p = $sth->fetchrow_hashref(NAME_lc)) {
    my $due = ($p->{net} || 0) - ($p->{paid} || 0);
    next unless $due > 0.005;

    my $dt = $p->{transdate};
    $dt =~ s/\D//g;
    $dt = substr($dt, 0, 8);
    next unless $dt && $to;

    my $days = _days_between($dt, $to);
    $days = 0 if $days < 0;

    # Collapse into selected buckets like stock SQL-Ledger aging.
    my $bucket = $active[-1];
    if ($#active == 0) {
      $bucket = $active[0];
    } elsif ($days <= $bound{$active[1]}) {
      $bucket = $active[0];
    } elsif ($days > $bound{$active[-1]}) {
      $bucket = $active[-1];
    } else {
      for my $i (1 .. $#active - 1) {
        if ($days > $bound{$active[$i]} && $days <= $bound{$active[$i + 1]}) {
          $bucket = $active[$i];
          last;
        }
      }
    }

    my $ref = {
      vc_id         => $p->{employee_id},
      vendornumber  => $p->{employeenumber} || '',
      name          => $p->{employee},
      address1      => '', address2 => '', city => '', state => '', zipcode => '', country => '',
      contact       => '',
      vendorphone   => '', vendorfax => '', vendortaxnumber => '',
      invdescription=> 'Sales commission',
      invnumber     => $p->{invnumber} || 'Commission',
      transdate     => _fmt_date($form, $myconfig, $p->{transdate}),
      till          => '',
      ordnumber     => '', ponumber => '', notes => '',
      duedate       => _fmt_date($form, $myconfig, $p->{transdate}),
      invoice       => 0,
      id            => -$p->{id},
      curr          => $curr,
      exchangerate  => 1,
      language_code => '',
      firstname     => '', lastname => '', salutation => '', typeofcontact => '',
    };
    for (@buckets) { $ref->{$_} = ($_ eq $bucket) ? $due : 0 }
    push @add, $ref;
  }
  $sth->finish;

  push @{ $form->{AG} }, @add;
  @{ $form->{AG} } = sort {
    ($a->{vc_id} <=> $b->{vc_id})
    || (($a->{transdate} || '') cmp ($b->{transdate} || ''))
    || (($a->{invnumber} || '') cmp ($b->{invnumber} || ''))
  } @{ $form->{AG} };
}

sub _days_between {
  my ($from, $to) = @_;
  # expects yyyymmdd
  return 0 unless $from =~ /^\d{8}$/ && $to =~ /^\d{8}$/;
  my @f = $from =~ /(\d{4})(\d{2})(\d{2})/;
  my @t = $to   =~ /(\d{4})(\d{2})(\d{2})/;
  require Time::Local;
  my $df = Time::Local::timegm(0,0,12,$f[2],$f[1]-1,$f[0]);
  my $dt = Time::Local::timegm(0,0,12,$t[2],$t[1]-1,$t[0]);
  return int(($dt - $df) / 86400);
}

1;
