# HTTPDtype.pl: retrieves http server headers
#       Author: Joey Smith <joey@php.net>
#    Licensing: Artistic License
#      Version: v0.1 (20031110)
#
use strict;

package HTTPDtype;

sub HTTPDtype {
    my ($HOST) = @_;
    my($line) = '';
    my($code, $mess, %h);

    $HOST = 'joeysmith.com' unless length($HOST) > 0;
    return unless &::loadPerlModule("Net::HTTP::NB");
    return unless &::loadPerlModule("IO::Select");

	my $s = Net::HTTP::NB->new(Host => $HOST) || return;
	$s->write_request(HEAD => "/");

	my $sel = IO::Select->new($s);
	$line = "Header timeout" unless $sel->can_read(10);
	($code, $mess, %h) = $s->read_response_headers;

	$line = (length($h{Server}) > 0) ? $h{Server} :
	  "Couldn't fetch headers from $HOST";

    &::pSReply($line||"Unknown Error Condition");

}

1;