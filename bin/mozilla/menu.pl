#=====================================================================
# SQL-Ledger
# Copyright (c) DWS Systems Inc.
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# two frame layout with refractured menu
#
#======================================================================

$menufile = "menu.ini";
use SL::Menu;

require "$form->{path}/js.pl";

1;
# end of main


sub display {
  
  $menuwidth = ($ENV{HTTP_USER_AGENT} =~ /links/i) ? "240" : "155";
  $menuwidth = $myconfig{menuwidth} if $myconfig{menuwidth};

  $form->header;

  print qq|

<FRAMESET COLS="$menuwidth,*" BORDER="1">

  <FRAME NAME="acc_menu" SRC="$form->{script}?login=$form->{login}&action=acc_menu&path=$form->{path}&js=$form->{js}">
  <FRAME NAME="main_window" SRC="am.pl?login=$form->{login}&action=$form->{main}&path=$form->{path}">

</FRAMESET>

</BODY>
</HTML>
|;

}


sub acc_menu {

  my $menu = new Menu "$menufile";
  $menu->add_file("$form->{path}/custom/$menufile") if -f "$form->{path}/custom/$menufile";
  $menu->add_file("$form->{path}/custom/$form->{login}/$menufile") if -f "$form->{path}/custom/$form->{login}/$menufile";

  $form->{title} = $locale->text('Accounting Menu');

  $form->header;

  print qq|
<script type="text/javascript">
function SwitchMenu(obj) {
  if (document.getElementById) {
    var el = document.getElementById(obj);

    if (el.style.display == "none") {
      el.style.display = "block"; //display the block of info
      el.setAttribute('data-display', 'display: block;');
    } else {
      el.style.display = "none";
      el.setAttribute('data-display', 'display: none;');
    }
  }
}

function ChangeClass(menu, newClass) {
  if (document.getElementById) {
    document.getElementById(menu).className = newClass;
  }
}

function SetActiveMenu(el) {
  var active = document.getElementsByClassName('menuActive');
  while (active.length) {
    active[0].className = 'submenu submenu-item';
  }
  var parent = el.parentNode;
  if (parent && parent.className.indexOf('submenu-item') !== -1) {
    parent.className = 'submenu submenu-item menuActive';
  }
}

function FilterMenu(value) {
  var term = value.toLowerCase();
  var items = document.getElementsByClassName('submenu-item');
  var i, j;
  for (i = 0; i < items.length; i++) {
    var text = items[i].textContent \|\| items[i].innerText;
    items[i].style.display = (!term \|\| text.toLowerCase().indexOf(term) !== -1) ? '' : 'none';
  }
  var groups = document.getElementsByClassName('submenu-group');
  for (var pass = 0; pass < 3; pass++) {
    for (i = groups.length - 1; i >= 0; i--) {
      var container = groups[i].querySelector('.submenu-container');
      var header = groups[i].querySelector('.menuOut, .menuOver');
      var any = false;
      var htxt = '';
      if (header) { htxt = (header.textContent \|\| header.innerText).toLowerCase(); }
      var headerMatch = term && htxt.indexOf(term) !== -1;
      if (container) {
        var children = container.getElementsByClassName('submenu-item');
        for (j = 0; j < children.length; j++) {
          if (children[j].style.display !== 'none') { any = true; }
        }
        var subgroups = container.children;
        for (j = 0; j < subgroups.length; j++) {
          if (subgroups[j].className && subgroups[j].className.indexOf('submenu-group') !== -1 && subgroups[j].style.display !== 'none') { any = true; }
        }
        if (headerMatch) {
          any = true;
          for (j = 0; j < children.length; j++) { children[j].style.display = ''; }
          for (j = 0; j < subgroups.length; j++) {
            if (subgroups[j].className && subgroups[j].className.indexOf('submenu-group') !== -1) { subgroups[j].style.display = ''; }
          }
        }
      }
      groups[i].style.display = (!term \|\| any) ? '' : 'none';
      if (header) { header.style.display = (!term \|\| any) ? '' : 'none'; }
      if (container) { container.style.display = term ? (any ? 'block' : 'none') : (container.getAttribute('data-display') \|\| 'none'); }
    }
  }
  var topHeaders = document.querySelectorAll('body > .menuOut');
  for (i = 0; i < topHeaders.length; i++) {
    var hdr = topHeaders[i];
    var onclick = hdr.getAttribute('onclick') \|\| '';
    var m = onclick.indexOf("SwitchMenu('sub");
    if (m === -1) {
      if (term) {
        var htxt = (hdr.textContent \|\| hdr.innerText).toLowerCase();
        hdr.style.display = htxt.indexOf(term) !== -1 ? '' : 'none';
      } else {
        hdr.style.display = '';
      }
      continue;
    }
    var id = onclick.substring(m + 12);
    id = id.substring(0, id.indexOf("'"));
    var cont = document.getElementById(id);
    if (!cont) { continue; }
    var any2 = false;
    var htxt2 = (hdr.textContent \|\| hdr.innerText).toLowerCase();
    var headerMatch2 = term && htxt2.indexOf(term) !== -1;
    var citems = cont.getElementsByClassName('submenu-item');
    for (j = 0; j < citems.length; j++) {
      if (citems[j].style.display !== 'none') { any2 = true; }
    }
    var cgroups = cont.querySelectorAll('.submenu-group');
    for (j = 0; j < cgroups.length; j++) {
      if (cgroups[j].style.display !== 'none') { any2 = true; }
    }
    if (headerMatch2) {
      any2 = true;
      for (j = 0; j < citems.length; j++) { citems[j].style.display = ''; }
      for (j = 0; j < cgroups.length; j++) { cgroups[j].style.display = ''; var gh = cgroups[j].querySelector('.menuOut, .menuOver'); if (gh) gh.style.display = ''; }
    }
    hdr.style.display = (!term \|\| any2) ? '' : 'none';
    cont.style.display = term ? (any2 ? 'block' : 'none') : (cont.getAttribute('data-display') \|\| 'none');
  }
  if (!term) {
    var cts = document.getElementsByClassName('submenu-container');
    for (i = 0; i < cts.length; i++) {
      cts[i].style.display = cts[i].getAttribute('data-display') \|\| 'none';
    }
  }
}
document.onselectstart = new Function("return false");
</script>

<body class=menu />

<img src=$images/sql-ledger.gif width=80 border=0>

<br>$myconfig{name}
<br><input type="text" id="menu-search" class="menu-search" placeholder="Search..." onkeyup="FilterMenu(this.value)">
|;

  if ($form->{js}) {
    &jsmenu_frame($menu);
  } else {
    &section_menu($menu);
  }

  print qq|
</body>
</html>
|;

}


sub section_menu {
  my ($menu, $level) = @_;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);

  while (@menuorder) {
    $item = shift @menuorder;
    $label = $item;
    $label =~ s/$level--//g;

    my $spacer = "&nbsp;" x (($item =~ s/--/--/g) * 2);

    $label =~ s/.*--//g;
    $label = $locale->text($label);

    # <hr> is a separator, not a hoverable menu item
    if ($item eq '<hr>') {
      print qq|<br><hr><br>\n|;
      next;
    }

    $label =~ s/ /&nbsp;/g if $label !~ /<img /i;

    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};
    
    if ($menu->{$item}{submenu}) {

      $menu->{$item}{$item} = !$form->{$item};

      if ($form->{level} && $item =~ $form->{level}) {

        # expand menu
	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a>|;

	# remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;
	
	&section_menu($menu, $item);

	print qq|<br>\n|;

      } else {

	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label&nbsp;...</a>|;

        # remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;

      }
      
    } else {
    
      if ($menu->{$item}{module}) {

	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a>|;
	
      } else {

        $form->{tag}++;
	print qq|<a name="id$form->{tag}"></a>
	<p><b>$label</b>|;
	
	&section_menu($menu, $item);

	print qq|<br>\n|;

      }
    }
  }
}



sub jsmenu_frame {
  my ($menu, $level) = @_;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);

  while (@menuorder){
    $i++;
    $item = shift @menuorder;
    $label = $item;
    $label =~ s/.*--//g;
    $label = $locale->text($label);

    # <hr> is a separator, not a hoverable menu item
    if ($item eq '<hr>') {
      print qq|<hr>\n|;
      next;
    }

    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};

    if ($menu->{$item}{submenu}) {
      
	$display = "display: none;" unless $level eq ' ';

	print qq|
        <div class="submenu-group">
        <div id="menu$i" class="menuOut" onclick="SwitchMenu('sub$i')" onmouseover="ChangeClass('menu$i','menuOver')" onmouseout="ChangeClass('menu$i','menuOut')">$label</div>
	<div class="submenu submenu-container" id="sub$i" style="$display" data-display="$display">|;
	
	# remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;

	&jsmenu_frame($menu, $item);
	
	print qq|
	</div>
        </div>
|;

    } else {

      if ($menu->{$item}{module}) {
	if ($level eq "") {
	  print qq|<div id="menu$i" class="menuOut" onmouseover="ChangeClass('menu$i','menuOver')" onmouseout="ChangeClass('menu$i','menuOut')"> |. 
	  $menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a></div>|;

	  # remove same level items
	  map { shift @menuorder } grep /^$item/, @menuorder;

          &jsmenu_frame($menu, $item);

	} else {
	
	  print qq|<div class="submenu submenu-item"> |.
          $menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a></div>|;
	}

      } else {

	$display = "display: none;" unless $item eq ' ';

	print qq|
<div id="menu$i" class="menuOut" onclick="SwitchMenu('sub$i')" onmouseover="ChangeClass('menu$i','menuOver')" onmouseout="ChangeClass('menu$i','menuOut')">$label</div>
	<div class="submenu submenu-container" id="sub$i" style="$display" data-display="$display">|;
	
	&jsmenu_frame($menu, $item);
	
	print qq|
	</div>
|;

      }

    }

  }

}


sub jsmenu {
  my ($menu, $level) = @_;
  
  # build menu_{login}.js for user
  my @menuorder = $menu->access_control(\%myconfig, $level);

  while (@menuorder){
    $item = shift @menuorder;
    $label = $item;
    $label =~ s/.*--//g;
    $label = $locale->text($label);

    next if $item eq '<hr>';

    if ($menu->{$item}{submenu}) {

      $form->{items} = 1;
      
      $form->{jsmenu} .= $form->{stagger};
      $form->{jsmenu} .= qq|['$label', null, null,\n|;
      
      # remove same level items
      map { shift @menuorder } grep /^$item/, @menuorder;

      $form->{stagger} .= "\t";

      &jsmenu($menu, $item);
      
      chop $form->{stagger};
      $form->{jsmenu} .= qq|$form->{stagger}],\n|;

    } else {

      if ($menu->{$item}{module}) {
	$form->{items} = 1;
	
	if ($level eq "") {

	  $menu->{$item}{jsmenu} = 1;
	  $str = $menu->menuitem(\%myconfig, \%$form, $item, $level);
	  $str =~ s/^<a href=//;
	  $str =~ s/>$//;

          $form->{jsmenu} .= $form->{stagger};
	  $form->{jsmenu} .= qq|['$label', '$str'],\n|;
	  
	  # remove same level items
	  map { shift @menuorder } grep /^$item/, @menuorder;

          &jsmenu($menu, $item);

	  $form->{jsmenu} .= qq|$form->{stagger}],\n|;
	  
	} else {
	
	  $menu->{$item}{jsmenu} = 1;
	  $str = $menu->menuitem(\%myconfig, \%$form, $item, $level);
	  $str =~ s/^<a href=//;
	  $str =~ s/>$//;
          $form->{jsmenu} .= $form->{stagger};
	  $form->{jsmenu} .= qq|['$label', '$str'],\n|;

	}

      } else {

        $form->{jsmenu} .= $form->{stagger};
	$form->{jsmenu} .= qq|['$label', null, null,\n|;
	$form->{stagger} .= "\t";
        
	&jsmenu($menu, $item);

	chop $form->{stagger};
        if ($form->{items}) {
	  $form->{jsmenu} .= qq|$form->{stagger}],\n|;
	} else {
	  $form->{jsmenu} =~ s/\t??\['$label', null, null,\s*$//;
	}
	$form->{items} = 0;
      }

    }

  }

}


sub menubar {

  1;

}


