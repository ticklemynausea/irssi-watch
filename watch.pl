#
# dalnet ircd WATCH implementation for irssi
# supports PTnet's NickServ extras
#
# Uses some client code from the original watch script by ThEbUtChE
# http://scripts.irssi.org/scripts/watch.pl
# Credits: thebutche@interec.org / http://www.nebulosa.org
#
# author:  neofreak@irc.ptnet.org
#  email: igotbugs@ticklemynausea.net 
#    web: http://www.ticklemynausea.net
#
#
#                     ,,__
#           ..  ..   / o._)                   .---.
#          /--'/--\  \-'||        .----.    .'     '.
#         /        \_/ / |      .'      '..'         '-.
#       .'\  \__\  __.'.'     .'          ì-._
#         )\ |  )\ |      _.'
#        // \\ // \\
#       ||_  \\|_  \\
#       '--' '--'' '--'
#
#
# BASED ON: http://mirc.org/mishbox/reference/rawhelp6.htm
# PTnet RFC (lol): http://ptnet.org/noticias_ptnet_novidades-na-rede
#
#
# Usage:
#
# /watch          : shows online/offline nicknames
# /watch update   : updates the server with your online nicknames
# /watch status   : shows the status of your watch list
# /watch add nick : adds the nick to your watch list
# /watch del nick : removes the nick from your watch list
# /watch help     : shows this help screen
#
# You will want to execute the "/watch update" command automatically
# on connect.
# 
# 

$VERSION = '3.0';
%IRSSI = (
 authors   => 'neofreak, ThEbUtChE',
 contact   => 'thebutche@interec.org, igotbugs@ticklemynausea.net',
 name    => 'Watch',
 description => 'Watch script for IRSSI.',
 license   => 'BSD',
 url     => 'http://www.ticklemynausea.net',
 changed   => 'June 2013',
 bugs    => 'igotbugs@ticklemynausea.net'
);

use warnings;
use strict;

use Irssi;
use Irssi::Irc;
use POSIX qw(floor);
use POSIX qw(strftime);
use DateTime::Duration;
use List::Util qw(max);
use Data::Dumper;

my %watchlist;
my @displaylist = ();
my $use_table = 0;
my $maxlength = 400;
my $msg_lb = "%K[%n";
my $msg_rb = "%K]%n";
my $watch = "Watch:";#
# misc. functions
#
################################################################################

# Checks if we're in PTnet
sub is_ptnet {
  my $server = shift;
  my $version = $server->{version};

  # expected: dal4.6.Based.PTnet1.7.00
  return $version =~ /PTnet/;
}

# Checks if we're cconnected
sub is_connected {
  my $server = Irssi::active_server();
  return defined $server;
}

# Checks if a nick is already saved in the watchlist file
sub is_in_list
{
  my ($ni) = @_;
  
  my $file = Irssi::get_irssi_dir."/watch";
  my @nick;
  
  local(*FILE);
  open FILE, "< $file";
  while (<FILE>) {
    @nick = split;
  if (lc($nick[0]) eq lc($ni)) { return 1; }
  }
  close FILE;
  return 0;
}

# Pads with spaces.
sub LPad {
  my ($str, $len, $chr) = @_;

  $chr = " " unless (defined($chr));
  return substr(($chr x $len) . $str, -1 * $len, $len);
}

sub RPad {
  my ($str, $len, $chr) = @_;
  $chr = " " unless (defined($chr));
  return substr($str . ($chr x $len), 0, $len);
}

sub draw_box {
  my ($title, $text, $footer, $colour, $maxlen_nick, $maxlen_logontimef, $maxlen_regtimef, $maxlen_mask) = @_;

  my $box = '';
  my $h1 = RPad("%W%UNick%U%c", $maxlen_nick+8, "-");
  my $h2 = RPad("%W%UOnline%U%c", $maxlen_logontimef+8, "-");
  my $h3 = RPad("%W%URegistration%U%c", $maxlen_regtimef+8, "-");
  my $h4 = RPad("%W%UMask%U%c", $maxlen_mask+8, "-");

  $box .= "%c+-$h1-+-";
  $box .= "$h2-+-";
  $box .= "$h3-+-";
  $box .= "$h4";
  $box .= '-+%n'."\n";
  foreach (split(/\n/, $text)) {
      $box .= '%c|%n '.$_."\n";
  }
  $box .= "%c+"."-" x ($maxlen_nick+2) ."%n";
  $box .= "%c+"."-" x ($maxlen_logontimef+2) ."%n";
  $box .= "%c+"."-" x ($maxlen_regtimef+2) ."%n";
  $box .= "%c+"."-" x ($maxlen_mask+2) ."+%n";
  $box =~ s/%.//g unless $colour;
  return $box;
} ## end sub draw_box

#sub to_period {
#  my ($logontime) = @_;
#  my $duration = time - $logontime;
#  return "$duration"."s";
#} ## end sub ToPeriod

sub to_period {

  my ($time) = @_; 
  $time = time - $time;

  if ($time < 0) {
    $time = 0;
  }

  my $weeks = 
  my $days = int($time / 86400); 
  $time -= ($days * 86400); 
  my $hours = int($time / 3600); 
  $time -= ($hours * 3600); 
  my $minutes = int($time / 60); 
  my $seconds = $time % 60; 

  $days = $days < 1 ? '' : $days .'d ';
  $hours = $hours < 1 ? '' : $hours .'h '; 
  $minutes = $minutes < 1 ? '' : $minutes . 'm ';

  my $str = ($days . $hours . $minutes . $seconds . 's'); 
  my $pos = index($str, " ");
  $pos = index($str, " ", $pos+1);
  if ($pos != -1) {
    $str = substr($str, 0, $pos);
  }
  return $str;
}

# Client code: command handling, etc
#
################################################################################

# /watch list
# Lists all nicknames saved in the watch list
sub cmd_watch_list
{
  my @nick;
  
  if (is_connected()) {
    $use_table = 1;
    Irssi::active_win()->command("quote watch l");
  } else {
    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    my $str = "";
    my $c = 0;
    local(*FILE);

    open FILE, "< $file";
    while (<FILE>) {
      @nick = split;
      $str .= " $nick[0]";
      $c = $c + 1;
    }

    close FILE;

    if ($c > 0) {
      Irssi::print "Watching %_$c%n nicknames:$str";
    } else {
      Irssi::print "Watch list is empty!";
    }
  }
}

sub cmd_watch_table
{
  my @nick;

  if (is_connected()) {
    $use_table = 1;
    Irssi::active_win()->command("quote watch l");
  } else {
    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    my $str = "";
    my $c = 0;
    local(*FILE);

    open FILE, "< $file";
    while (<FILE>) {
      @nick = split;
      $str .= " $nick[0]";
      $c = $c + 1;
    }

    close FILE;

    if ($c > 0) {
      Irssi::print "Watching %_$c%n nicknames:$str";
    } else {
      Irssi::print "Watch list is empty!";
    }
  }
}

sub cmd_watch_status {
  Irssi::active_win()->command("quote watch s");
}

# /watch add
# Adds a nickname to the watch list
sub cmd_watch_add
{
  my ($nick) = @_;
  my($file) = Irssi::get_irssi_dir."/watch";
  local(*FILE);
  if ($nick eq "") { Irssi::print "Please choose a nickname."; return; 
  } elsif (is_in_list($nick)) { Irssi::print "The nickname is already on the watchlist."; return; }

  open FILE, ">> $file";
        print FILE join("\t","$nick\n");
  close FILE;

  if (is_connected) {
    Irssi::active_win()->command("quote watch +$nick");
  } else {
    Irssi::print "Nick %_$nick%n has been added to the.";
  }
}

# /watch del
# Removes a nickname from watch
sub cmd_watch_del
{
  my ($ni) = @_;

  my @nick;
  my $file = Irssi::get_irssi_dir."/watch";
  my $file2 = Irssi::get_irssi_dir."/.watch-temp";

  local(*FILE);
  local(*FILE2);
  
  if ($ni eq "") { 
    Irssi::print "Please choose a nickname."; 
    return;
  } elsif (!is_in_list($ni)) { 
    Irssi::print "The nickname isn't on the watchlist.";
    return;
  }

  open FILE2, "> $file2";
    print FILE2 "";
  close FILE2;

  open FILE, "< $file";
  open FILE2, ">> $file2";

  while (<FILE>) {
    @nick = split;
    if (lc($nick[0]) eq lc($ni)) { 
    } else {
      print FILE2 join("\t","$nick[0]\n");
    }
  }

  close FILE;
  close FILE2;

  open FILE, "> $file";
  print FILE "";
  close FILE;

  open FILE, ">> $file";
  open FILE2, "< $file2";

  while (<FILE2>) {
    @nick = split;
    print FILE join("\t","$nick[0]\n");
  }

  close FILE;
  close FILE2;

  Irssi::active_win()->command("quote watch -$ni");

  if (!is_connected()) {
    Irssi::print "Nick %9$ni%9 was removed from the watch list.";
  }

}

#
# /watch command
# Main watch command
sub cmd_watch 
{
  my ($arg) = @_;
  my ($cmd, $nick) = split(/ /, $arg);

  if (not defined $cmd) {
    $cmd = "list";
  }

  if ($cmd eq "help") {
    cmd_watch_help();
  } elsif ($cmd eq "add") {
    cmd_watch_add($nick);
  } elsif ($cmd eq "del") {
    cmd_watch_del($nick);
  } elsif ($cmd eq "update") {
    cmd_watch_load();
  } elsif ($cmd eq "debug") {
    print Dumper(\%watchlist);
  } elsif ($cmd eq "status") {
    cmd_watch_status();
  } else {
    cmd_watch_list();
  }
}

sub cmd_watch_load
{
  my $file = Irssi::get_irssi_dir."/watch";
  my @nick;
  my $leftovers;
  my $command;

  local(*FILE);
  open FILE, "< $file";
  
  $command = "quote watch ";
  while (<FILE>) {

    @nick = split;
    $command .= "+$nick[0] ";
    $leftovers = 1;

    if (length($command) > $maxlength) {
      Irssi::active_win()->command($command);
      $leftovers = 0;
      $command = "quote watch ";
    }
  }

  if ($leftovers == 1) {
    Irssi::active_win()->command($command);
  }

  close FILE;

}

sub cmd_watch_help 
{
 Irssi::print " Usage:";
 Irssi::print "   /watch          : shows online/offline nicknames";
 Irssi::print "   /watch update   : updates the server with your online nicknames";
 Irssi::print "   /watch status   : shows the status of your watch list";
 Irssi::print "   /watch add nick : adds the nick to your watch list";
 Irssi::print "   /watch del nick : removes the nick from your watch list";
 Irssi::print "   /watch help     : shows this help screen";
}

# Sends the WATCH l or WATCH s command
sub server_watch
{
  my ($w) = @_;
  Irssi::active_win()->command("quote watch $w");
}

#
# IRC Raw Events! 601 - 608
#
# 600
sub event_rpl_logon
{
  my ($server, $data) = @_;
  my ($me, $nick, $user, $host, $logontime) = split(/ /, $data);

  # if the network is PTnet then we want to save the output for the 608
  # that comes.
  if (is_ptnet($server)) {
    $watchlist{$nick} = {user => $user, host => $host, origin => '600'};
  } else {
    $server->print("", "$watch %g$nick%K [%n$user\@$host%K] %9logged on", MSGLEVEL_CRAP);
  }
}

# 601
sub event_rpl_logoff 
{
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  $server->print("", "$watch %R$nick%n logged off", MSGLEVEL_CRAP);
}

# 602
sub event_rpl_watchoff {
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  $server->print("", "Nick %_$nick%n was removed from the watch list.", MSGLEVEL_CRAP);
}

# 603
sub event_rpl_watchstat {
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  my $msg = substr($data, index($data, ':') + 1);
  $server->print("", "$watch %_$msg%n", MSGLEVEL_CRAP);
}

# 604 
sub event_rpl_nowon {
  my ($server, $data) = @_;
  my ($me, $nick, $user, $host, $logontime) = split(/ /, $data);
  # if the network is PTnet then we want to save the output for the 608
  # that comes.
  if (is_ptnet($server)) {
    $watchlist{$nick} = {user => $user, host => $host, origin => '604', logontime => $logontime};
  } else {
    my $mask = "$user"."@"."$host";
    $server->print("", "$watch %g$nick%n $msg_lb$mask$msg_rb is online!", MSGLEVEL_CRAP);
  }
 
}

# 605
sub event_rpl_nowoff {
  my ($server, $data) = @_;
  my ($me, $nick, $ident, $host) = split(/ /, $data);

  $server->print("", "$watch %R$nick%n is offline!", MSGLEVEL_CRAP);
}

# 606
sub event_rpl_watchlist {
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  my $msg = substr($data, index($data, ':') + 1);
  $server->print("", "$watch %_Watching:%n $msg", MSGLEVEL_CRAP);
}

# 607
sub event_rpl_endofwatchlist {

  sub by_logontime {
    $a->{logontime} <=> $b->{logontime}
  }

  sub by_regtime {
    $a->{regtime} <=> $b->{regtime}
  }

  sub by_nick {
    $a->{nick} <=> $b->{nick}
  }

  my ($server, $data) = @_;
  my $msg = substr($data, index($data, ' ') + 1);
  my $string = "";

  # End of WATCH list. Sort list and format it to display in a table
  if (($msg =~ /End of WATCH l/) and ($use_table == 1) and $#displaylist > 0 and is_ptnet($server)) {  

    $use_table = 0;

    # Calculate padding values
    my $maxlen_nick = max map { length($_->{nick}) } @displaylist;
    my $maxlen_logontimef = max map { length($_->{logontimef}) } @displaylist;
    my $maxlen_regtimef = max map { length($_->{regtimef}) } @displaylist;
    my $maxlen_mask = (max map { length($_->{user}) + length($_->{host}) } @displaylist) + 1;
    my @sorted = sort by_logontime @displaylist;
    foreach (@sorted) { 
      my $nick = $_->{nick};
      my $mask = "$_->{user}\@$_->{host}";
      my $regtime = $_->{regtime};
      my $logontime =  $_->{logontime};
      my $regtimef = $_->{regtimef};
      my $logontimef = $_->{logontimef};
      my $color = "%g";

      # lool PTnet is funny and returns a weird value for NickServ etc lelele
      if ($regtime eq 301097) {
        $color = "%G";
        $regtimef = "services nickname";
      } elsif ($regtime == 0) {
        $color = "%R";
        $regtimef = "not identified";
      }

      my $padded_nick = RPad($nick, $maxlen_nick);
      my $padded_logontimef = RPad($logontimef, $maxlen_logontimef);
      my $padded_regtimef = RPad($regtimef, $maxlen_regtimef);
      my $padded_mask = RPad($mask, $maxlen_mask);
      $string .= "$color$padded_nick %c|%n $padded_logontimef %c|%n $padded_regtimef %c|%n $padded_mask %c|%n\n";
    }

    my $box = draw_box("Watch", $string, "Watch", 4, $maxlen_nick, $maxlen_logontimef, $maxlen_regtimef, $maxlen_mask); 

    #clear display list after use
    @displaylist = ();

    $server->print("", $box, MSGLEVEL_CRAP);
    #$server->print("", "End of %_watch list%n", MSGLEVEL_CRAP);

  } elsif ($msg =~ /End of WATCH l/) {
    $server->print("", "End of %_watch list%n", MSGLEVEL_CRAP);
  } elsif ($msg =~ /End of WATCH s/) {
    $server->print("", "End of %_watch status%n", MSGLEVEL_CRAP);
  }
}

# 608
# Always follows a 600 or 604 (in PTnet only)
sub event_rpl_watchnickserv {
  my ($server, $data) = @_;
  my ($me, $nick, $regtime) = split(/ /, $data);

  if ($use_table == 0) {

    my $mask = "$watchlist{$nick}{user}\@$watchlist{$nick}{host}";
    my $regtimef = strftime('%b %d %H:%M:%S %Y', localtime($regtime));
    my $color = "%g";

    # lool PTnet is funny and returns a weird value for NickServ etc lelele
    if ($regtime eq 301097) {
      $color = "%G";
      $regtimef = "services nickname";
    } elsif ($regtime == 0) {
      $color = "%R";
      $regtimef = "not identified";
    }

    if ($watchlist{$nick}{origin} == 600) {
      $server->print("", "$watch $color$nick%n $msg_lb"."since $regtimef ($mask)$msg_rb logged on!", MSGLEVEL_CRAP);
    } else {
      $server->print("", "$watch $color$nick%n $msg_lb"."since $regtimef ($mask)$msg_rb is online!", MSGLEVEL_CRAP);
    }

  } else {
    if ($watchlist{$nick}{origin} == 604) {
      push(@displaylist, {
        nick => $nick,
        user => $watchlist{$nick}{user},
        host => $watchlist{$nick}{host},
        logontime => $watchlist{$nick}{logontime}, 
        logontimef => to_period($watchlist{$nick}{logontime}), 
        regtime => $regtime,
        regtimef => strftime('%b %d %H:%M:%S %Y', localtime($regtime))
      });
    }

  }
}

Irssi::command_bind('watch', 'cmd_watch');
#Irssi::signal_add_last('event connected', 'watch_load');

Irssi::signal_add('event 600', 'event_rpl_logon');
Irssi::signal_add('event 601', 'event_rpl_logoff');
Irssi::signal_add('event 602', 'event_rpl_watchoff');
Irssi::signal_add('event 603', 'event_rpl_watchstat');;
Irssi::signal_add('event 604', 'event_rpl_nowon');
Irssi::signal_add('event 605', 'event_rpl_nowoff');
Irssi::signal_add('event 606', 'event_rpl_watchlist');
Irssi::signal_add('event 607', 'event_rpl_endofwatchlist');

Irssi::signal_add('event 608', 'event_rpl_watchnickserv'); # PTnet!

Irssi::settings_add_str('watch', 'nicknames', '');


#
# Contains ascii art by:
#   http://www.chris.com/ascii/index.php?art=animals/camels
#
