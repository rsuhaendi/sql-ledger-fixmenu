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
  my $source = $dbh->quote($ref->{invnumber} || 'Commission');
  my $memo = $dbh->quote("Sales commission - $ref->{invnumber}");

  $dbh->do(qq|UPDATE ar SET
                commission_amount = $gross,
                commission_deduction = $deduction,
                commission_net = $net,
                commission_posted = true
              WHERE id = $id|);

  for my $entry (
      ['5480', -$gross],
      ['2290',  $net],
      ['4490',  $cut]) {
    my ($accno, $amount) = @$entry;
    next unless $amount;

    $dbh->do(qq|INSERT INTO acc_trans
                  (trans_id, chart_id, amount, transdate, source, memo, approved)
                VALUES ($id, (SELECT id FROM chart WHERE accno = '$accno'),
                        $amount, '$transdate', $source, $memo, 't')|);
  }

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

  my $dbh = $form->dbconnect($myconfig);

  my $where = '';
  if ($form->{fromdate}) {
    $where .= " AND a.datepaid >= ".$dbh->quote($form->{fromdate});
  }
  if ($form->{todate}) {
    $where .= " AND a.datepaid <= ".$dbh->quote($form->{todate});
  }

  my $query = qq|
    SELECT e.id, e.name, e.commission_amount AS rate,
           count(*) AS invoices,
           sum(a.commission_amount) AS gross,
           sum(a.commission_amount - a.commission_net) AS deduction,
           sum(a.commission_net) AS net
    FROM ar a
    JOIN employee e ON (e.id = a.employee_id)
    WHERE a.commission_posted = true
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
    SELECT a.datepaid, a.invnumber, e.name, a.commission_amount AS gross,
           a.commission_deduction AS deduction, a.commission_net AS net
    FROM ar a
    JOIN employee e ON (e.id = a.employee_id)
    WHERE a.commission_posted = true
      AND a.paid >= a.amount
      $where
    ORDER BY a.datepaid, a.invnumber
  |;
  $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{CM_detail} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;
}

1;
