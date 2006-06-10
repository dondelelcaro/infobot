# WWW::Scraper backend, replaces W3Search.pl functionality.
# Uses WWW::Scraper and associated modules instead of WWW::Search;

# Written by Don Armstrong <don@donarmstrong.com>

# $Id$

package W3Scraper;

=head1 NAME

W3Scraper - blootbot plugin to do searches using WWW::Scraper

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use warnings;
use strict;
use vars qw ($VERSION);

my $maxshow = 5;

sub W3Scraper {
     my ($where,$what,$type) = @_;

     # rip out the available engines by brute force.
     my @matches = grep {/$where.pm/i and !/FieldTranslation/i and !/Re(sponse|quest)/i and !/TidyXML/i}
	  split /\n/, qx(ls /usr/share/perl5/WWW/Scraper);

     if (@matches) {
	  $where = shift @matches;
	  $where =~ s/\.pm//;
     }
     else {
	  &::msg($::who, "i don't know how to check '$where'");
	  return;
     }

     return unless &::loadPerlModule("WWW::Scraper");

     my $scraper;
     eval {
	  $scraper = new WWW::Scraper($where,$what);
     };
     if (not defined $scraper) {
	  &::msg($::who,"$where is an invalid search.");
	  return;
     }

     my $count = 0;
     my $results = q();
     while (my $result = $scraper->next_response()) {
	  next if not defined $result->url or not defined ${$result->url};
	  next if ((length ${$result->url}) > 80); #ignore long urls
	  if ($count > 0) {
	       $results .= ' or ';
	  }
	  $results .= ${$result->url};
	  last if ++$count > $maxshow;
     }
     if ($count > 0) {
	  $results = qq($where says "$what" is at $results [).
	       $scraper->approximate_result_count().
		    q( results]);
     }
     else {
	  $results = qq($where was unable to find "$what");
     }
     &::performStrictReply($results);
}


1;
