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

use Irssi;
use Irssi::Irc;
use POSIX qw(floor);
use POSIX qw(strftime);
use Data::Dumper;

our %watchlist = {};
my $maxlength = 400;
my $msg_lb = "%K[%n";
my $msg_rb = "%K]%n";

#
# misc. functions
#
################################################################################

# Checks if we're in PTnet
sub is_ptnet {
  my $server = Irssi::active_server();
  my $version = $server->{version};

  # expected: dal4.6.Based.PTnet1.7.00
  return $version =~ /PTnet/;
}

# Checks if we're cconnected
sub is_connected {
  my $server = Irssi::active_server();

  return $server != null;
}

# Prints crap.
sub irssi_output {
  my $server = Irssi::active_server();

  if (is_connected()) {
    my $tag = $server->{tag};
    Irssi::print "%K[%n$tag%K]%n @_", MSGLEVEL_SNOTES
  } else {
    Irssi::print "@_", MSGLEVEL_SNOTES
  }
}

# Checks if a nick is already saved in the watchlist file
sub is_in_list
{
  my ($ni) = @_;

  my($file) = Irssi::get_irssi_dir."/watch";
  my($nick);
  local(*FILE);
  open FILE, "< $file";
  while (<FILE>) {
    @nick = split;
  if (lc(@nick[0]) eq lc($ni)) { return 1; }
  }
  close FILE;
  return 0;
}

# Pads a nickname with spaces.
sub LPad {
  local($str, $len, $chr) = @_;
  $chr = " " unless (defined($chr));
  return substr(($chr x $len) . $str, -1 * $len, $len);
}

#
# Client code: command handling, etc
#
################################################################################

# /watch list
# Lists all nicknames saved in the watch list
sub cmd_watch_list
{
  if (is_connected()) {
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
      $str .= " @nick[0]";
      $c = $c + 1;
    }

    close FILE;

    if ($c > 0) {
      irssi_output "Watching %_$c%n nicknames:$str";
    } else {
      irssi_output "Watch list is empty!";
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
  if ($nick eq "") { irssi_output "Please choose a nickname."; return; 
  } elsif (is_in_list($nick)) { irssi_output "The nickname is already on the watchlist."; return; }

  open FILE, ">> $file";
        print FILE join("\t","$nick\n");
  close FILE;

  if (is_connected) {
    Irssi::active_win()->command("quote watch +$nick");
  } else {
    irssi_output "Nick %_$nick%n has been added to the.";
  }
}

# /watch del
# Removes a nickname from watch
sub cmd_watch_del
{
  my ($ni) = @_;
  my($file) = Irssi::get_irssi_dir."/watch";
  my($file2) = Irssi::get_irssi_dir."/.watch-temp";
  local(*FILE);
  local(*FILE2);
  
  if ($ni eq "") { 
    irssi_output "Please choose a nickname."; 
    return;
  } elsif (!is_in_list($ni)) { 
    irssi_output "The nickname isn't on the watchlist.";
    return;
  }

  open FILE2, "> $file2";
    print FILE2 "";
  close FILE2;

  open FILE, "< $file";
  open FILE2, ">> $file2";

  while (<FILE>) {
    @nick = split;
    if (lc(@nick[0]) eq lc($ni)) { 
    } else {
      print FILE2 join("\t","@nick[0]\n");
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
    print FILE join("\t","@nick[0]\n");
  }

  close FILE;
  close FILE2;

  Irssi::active_win()->command("quote watch -$ni");

  if (!is_connected()) {
    irssi_output "Nick %9$ni%9 was removed from the watch list.";
  }

}

#
# /watch command
# Main watch command
sub cmd_watch 
{
  my ($arg) = @_;
  my ($cmd, $nick) = split(/ /, $arg);

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
  my $nick;
  my $leftovers;
  my $command;

  local(*FILE);
  open FILE, "< $file";
  
  $command = "quote watch ";
  while (<FILE>) {

    @nick = split;
    $command .= "+@nick[0] ";
    $leftovers = 1;

    if (length($command) > $maxlength) {
      Irssi::active_win()->command($command);
      $leftovers = 0;
      $command = "quote watch ";
    }
  }

  if ($leftovers = 1) {
    Irssi::active_win()->command($command);
  }
  
  close FILE;
  chop $ret;

}

sub cmd_watch_help 
{
 irssi_output " Usage:";
 irssi_output "   /watch          : shows online/offline nicknames";
 irssi_output "   /watch update   : updates the server with your online nicknames";
 irssi_output "   /watch status   : shows the status of your watch list";
 irssi_output "   /watch add nick : adds the nick to your watch list";
 irssi_output "   /watch del nick : removes the nick from your watch list";
 irssi_output "   /watch help     : shows this help screen";
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
  my ($me, $nick, $ident, $host) = split(/ /, $data);

  # if the network is PTnet then we want to save the output for the 608
  # that comes.
  if (is_ptnet()) {
    $watchlist{$nick} = { 'ident' => $ident, 'host' => $host, 'origin' => '600' };
  } else {
    irssi_output "%G$nick%K [%n$ident\@$host%K]%G %9logged on";
  }
}

# 601
sub event_rpl_logoff 
{
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  irssi_output "%R$nick%n logged off";
}

# 602
sub event_rpl_watchoff {
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  irssi_output "Nick %_$nick%n was removed from the watch list.";
}

# 603
sub event_rpl_watchstat {
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  my $msg = substr($data, index($data, ':') + 1);
  irssi_output "%_$msg%n";
}

# 604 
sub event_rpl_nowon {
  my ($server, $data) = @_;
  my ($me, $nick, $ident, $host) = split(/ /, $data);
 
  # if the network is PTnet then we want to save the output for the 608
  # that comes.
  if (is_ptnet()) {
    $watchlist{$nick} = { 'ident' => $ident, 'host' => $host, 'origin' => '604'};
  } else {
    irssi_output "%G$nick%K [%n$ident\@$host%K]%G %9is online!";
  }
 
}

# 605
sub event_rpl_nowoff {
  my ($server, $data) = @_;
  my ($me, $nick, $ident, $host) = split(/ /, $data);

  irssi_output "%R$nick%n is offline!";
}

# 606
sub event_rpl_watchlist {
  my ($server, $data) = @_;
  my ($me, $nick) = split(/ /, $data);

  my $msg = substr($data, index($data, ':') + 1);
  irssi_output "%_Watching:%n $msg";
}

# 607
sub event_rpl_endofwatchlist {
  my ($server, $data) = @_;
  
  my $msg = substr($data, index($data, ' ') + 1);
  
  if ($msg =~ /WATCH l/) {
    irssi_output "End of %_watch list%n";
  } elsif ($msg =~ /End of WATCH s/) {
    irssi_output "End of %_watch status%n";
  }
}

# 608
# PTnet only
sub event_rpl_watchnickserv {
  my ($server, $data) = @_;
  my ($me, $nick, $regtime) = split(/ /, $data);
  my $mask, $event_str;

  $mask = "$watchlist{$nick}{'ident'}\@$watchlist{$nick}{'host'}";
  if ($watchlist{$nick}{'origin'} == 600) {
    $event_str = "logged on!"
  } else {
    $event_str = "is online"
  }
  

  #$nick = LPad($key, 15);
  # lool PTnet is funny and returns a weird value for NickServ etc lelele
  if ($regtime eq 301097) {
    #irssi_output "%G>> $nick %K$msg_lb%n$mask%K$msg_rb%n is online%n %K/%n %BServices Nickname";
    irssi_output "%G$nick%n $msg_lb"."Services Nickname ($mask) Services Nickname)$msg_rb $event_str";
  } elsif ($regtime > 0) {
    $regtimef = strftime('%b %d %H:%M:%S %Y', localtime($regtime));
    irssi_output "%G$nick%n $msg_lb"."since $regtimef ($mask)$msg_rb $event_str";
  } elsif ($regtime == 0) {
    #irssi_output "%G>> $nick %K$msg_lb%n$mask%K$msg_rb%n is online%n %K/%n %Rnot registered or identified%n";
    irssi_output "%R$nick%n $msg_lb"."not registered or not identified ($mask)$msg_rb $event_str";
  } else {
    irssi_output "%RError:%n unknown value for regtime in RAW_608";
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
