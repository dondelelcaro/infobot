# This program is distributed under the same terms as infobot.
# hacked by Tim@Rikers.org

package translate;
use strict;

my $no_translate;
my $url = 'http://translate.google.com/translate_a/t';

BEGIN {
	eval "use URI::Escape";	# utility functions for encoding the
	if ($@) { $no_translate++ }
	eval "use LWP::UserAgent";
	if ($@) { $no_translate++ }
	eval "use JSON";
	if ($@) { $no_translate++ }
}

sub translateParam {
	return '' if $no_translate;
	my ( $from, $to, $phrase ) = @_;
	&::DEBUG("translate($from, $to, $phrase)");

	my $ua = new LWP::UserAgent;
	$ua->proxy( 'http', $::param{'httpProxy'} ) if ( &::IsParam('httpProxy') );

	# Let's pretend
	$ua->agent( "Mozilla/5.0 " . $ua->agent );
	$ua->timeout(5);

	my $req = HTTP::Request->new('GET', 'http://translate.google.com/translate_a/t?client=t&ie=UTF-8&oe=UTF-8&sl='.$from.'&tl='.$to.'&text='.$phrase);

	$req->header('Accept-Language' => 'en-us');
	$req->header('Accept-Charset' => 'UTF-8,*');
	my $json = JSON->new->utf8;
	my $json_text=$ua->request($req)->content;
	$json_text =~ s/,,/,"",/g;
	$json_text =~ s/,,/,"",/g;
	#&::DEBUG($json_text);
	my @decoded_json = from_json($json_text);

	return $decoded_json[0][0][0][0];
}

sub translate {
	my ($message) = @_;
	if ($message =~ m{(\S*)\s+(\S*)\s+(.+)}xoi) {
		&::performStrictReply( &translateParam( lc $1, lc $2, lc $3 ) );
	}
	return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
