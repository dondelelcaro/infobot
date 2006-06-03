# WWWSearch backend, with queries updating the is-db (optionally)
# Uses WWW::Search::Google and WWW::Search
# originally Google.pl, drastically altered.

package W3Search;

use strict;
use vars qw(@W3Search_engines $W3Search_regex);
@W3Search_engines = qw(AltaVista Dejanews Excite Gopher HotBot Infoseek
		Lycos Magellan PLweb SFgate Simple Verity Google);
$W3Search_regex = join '|', @W3Search_engines;

my $maxshow	= 5;

sub W3Search {
    my ($where, $what, $type) = @_;
    my $retval = "$where can't find \002$what\002";
    my $Search;

    my @matches = grep { lc($_) eq lc($where) ? $_ : undef } @W3Search_engines;
    if (@matches) {
	$where = shift @matches;
    } else {
	&::msg($::who, "i don't know how to check '$where'");
	return;
    }

    return unless &::loadPerlModule("WWW::Search");

    eval {
	if ($where eq 'Google') {
	    # key is your Google API key.
	    # Get it from http://api.google.com/createkey
	    $Search = new WWW::Search('Google',key => '')
	}
	else {
	    $Search	= new WWW::Search($where);
	}
	if (!defined $Search) {
	    &::msg($::who, "$where is invalid search.");
	    return;
	}
	
	my $Query	= WWW::Search::escape_query($what);
	$Search->native_query($Query,{   num => 10,
					 search_debug => 2,
					 search_parse_debug => 2,
				     }
	);
	$Search->http_proxy($::param{'httpProxy'}) if (&::IsParam("httpProxy"));
	#my $max = $Search->maximum_to_retrieve(10);	# DOES NOT WORK.

	my (@results, $count, $r);
	$count=0;
	$retval = "$where says \002$what\002 is at ";
	while ($r = $Search->next_result()) {
	    my $url = $r->url();
	    $retval .= ' or ' if ($count > 0);
	    $retval .= $url;
	    last if ++$count >= $maxshow;
	}
	
	$retval = "$where was unable to find any results for \002$what\002" unless $count > 0;
	
	&::performStrictReply($retval);
    }
}    
1;
    
