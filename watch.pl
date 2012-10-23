# Watch script para irssi

# watch script consiste en un pequeño script que interpreta
# este novedoso sistema de notify que nos evita la tarea de
# tener que comprobar cada X tiempo si alguien de nuestro notify
# esta en el irc, este script solamente podra ser usado en redes
# que lo permitan, como por ejemplo irc-hispano.

$VERSION = '1.0';
%IRSSI = (
 authors     => 'ThEbUtChE',
 contact     => 'thebutche@interec.org',
 name        => 'Watch script',
 description => 'Uso del comando watch para irssi.',
 license     => 'BSD',
 url         => 'http://www.nebulosa.org',
 changed     => 'viernes, 17 de enero de 2003, 03:19:15 CET',
 bugs        => 'ninguno'
);

use Irssi;
use Irssi::Irc;
use Irssi::TextUI;
use POSIX qw(floor);
use POSIX qw(strftime);

our @stack = qw();

sub watch_list
{
    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    local(*FILE);

    open FILE, "< $file";
    while (<FILE>) {
	@nick = split;
	Irssi::print "Notify \002@nick[0]\002";
    }
    close FILE;
}

sub esta_notify
{
	my ($ni) = @_;

    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    local(*FILE);
    open FILE, "< $file";
    while (<FILE>) {
        @nick = split;
	if (@nick[0] eq $ni) { return 1; }
    }
    close FILE;
return 0;
}

sub watch_add
{
	my ($nick) = @_;
	my($file) = Irssi::get_irssi_dir."/watch";
    local(*FILE);
	if ($nick eq "") { Irssi::print "Please choose a nickname."; return; 
	} elsif (esta_notify($nick)) { Irssi::print "The nickname is already on the watchlist."; return; }

    open FILE, ">> $file";
                print FILE join("\t","$nick\n");
    close FILE;
Irssi::print "The nick $nick has been added.";
Irssi::active_win()->command("quote watch +$nick");

}

sub watch_del
{
	my ($ni) = @_;
        my($file) = Irssi::get_irssi_dir."/watch";
        my($file2) = Irssi::get_irssi_dir."/.watch-temp";
	    local(*FILE);
	    local(*FILE2);
        if ($ni eq "") { Irssi::print "Please choose a nickname."; return;
        } elsif (!esta_notify($ni)) { Irssi::print "The nickname isn't on the watchlist."; return; }

    open FILE2, "> $file2";
        print FILE2 "";
    close FILE2;

    open FILE, "< $file";
    open FILE2, ">> $file2";
    while (<FILE>) {
        @nick = split;
        if (@nick[0] eq $ni) { 
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
Irssi::print "The nick \002$ni\002 has been deleted.";

}

sub watch_list_online
{
Irssi::active_win()->command("quote watch l");
}

sub watch 
{
	my ($arg) = @_;
	my ($cmd, $nick) = split(/ /, $arg);
	if ($cmd eq "list") {
		watch_list();
	} elsif ($cmd eq "add") {
		watch_add($nick);
	} elsif ($cmd eq "del") {
		watch_del($nick);
	} elsif ($cmd eq "update") {
		watch_load();
	} else {
		watch_list_online();
	}
}

sub watch_load
{
    my($file) = Irssi::get_irssi_dir."/watch";
    my($nick);
    local(*FILE);
	my $ret;
    open FILE, "< $file";
    while (<FILE>) {
        @nick = split;
	$ret .= "+@nick[0] ";
    }
	chop $ret;
	Irssi::print("Sending watch command: watch $ret");
	Irssi::active_win()->command("quote watch $ret");
    close FILE;
}

sub event_is_online
{
	my ($server, $data) = @_;
	my ($me, $nick, $ident, $host) = split(/ /, $data);
	
	#push(@stack, "%g$nick%n");
	Irssi::print "\002$nick\002 \0034[\003\002\002$ident\@$host\0034]\003 \0033is on IRC";
}

sub event_is_offline
{
	my ($server, $data) = @_;
	my ($me, $nick) = split(/ /, $data);


	#push(@stack, "%r$nick%n");
	Irssi::print "\002$nick\002 \0034has left IRC";
}

sub null
{

}

sub event_is_online_regnick {
	my ($server, $data) = @_;
	my ($me, $nick, $regtime) = split(/ /, $data);

	if ($regtime eq 301097) {
		Irssi::print "$nick is online \0032and identified with a special value for the regtime.";
	} elsif ($regtime > 0) {
		$regtimef = strftime('%b %d %H:%M:%S %Y', localtime($regtime));
		Irssi::print "$nick is online \0033and has registered to NickServ in $regtimef";
	} else {
		Irssi::print "$nick is online \0034but not identified to NickServ!";
	}	
}
Irssi::command_bind('watch', 'watch');
#Irssi::signal_add_last('event connected', 'watch_load');
Irssi::signal_add('event 604', 'event_is_online');
Irssi::signal_add('event 605', 'null');
Irssi::signal_add('event 601', 'event_is_offline');
Irssi::signal_add('event 600', 'event_is_online');
Irssi::signal_add('event 608', 'event_is_online_regnick');


# Statusbar Item

sub watch_queue {
	my ($sb_item, $get_size_only) = @_;
	my $sb;

	$sb = "".@stack;
	$sb = substr($sb, 30);
# all draw functions should end with a call to default_handler().
	$sb_item->default_handler($get_size_only, "{sb $sb}", '', 0);
}

#Irssi::statusbar_item_register ('watch_queue', 0, 'watch_queue');
