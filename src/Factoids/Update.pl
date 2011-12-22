#
# Update.pl: Add or modify factoids in the db.
#    Author: Kevin Lenzo
#	     dms
#   Version: 19991209
#   Created: 1997
#

# use strict;	# TODO

use Encode qw(decode_utf8 encode_utf8);

sub update {
    my ( $lhs, $mhs, $rhs ) = @_;

    my $lhs_utf8 = decode_utf8($lhs);
    my $rhs_utf8 = decode_utf8($rhs);

    $lhs_utf8 =~ s/^i (heard|think) //i;
    $lhs_utf8 =~ s/^some(one|1|body) said //i;
    $lhs_utf8 =~ s/\s+/ /g;

    for my $temp ($lhs_utf8,$rhs_utf8 ) {
	if ($temp =~ /([^[:print:]])/ or $temp =~ /(\N{U+FFFD})/) {
	    &status("statement: illegal character '$1' ".ord($1).".");
	    &performAddressedReply(
		 "i'm not going to learn illegal characters");
	    return;
	}
    }
    # update rhs and lhs
    $rhs = encode_utf8($rhs_utf8);
    $lhs = encode_utf8($lhs_utf8);

    # locked.
    return if ( &IsLocked($lhs) == 1 );

    # profanity.
    if ( &IsParam('profanityCheck') and &hasProfanity($rhs_utf8) ) {
        &performReply("please, watch your language.");
        return 1;
    }

    # teaching.
    if ( &IsFlag('t') ne 't' && &IsFlag('o') ne 'o' ) {
        &msg( $who, "permission denied." );
        &status("alert: $who wanted to teach me.");
        return 1;
    }

    # invalid verb.
    if ( $mhs !~ /^(is|are)$/i ) {
        &ERROR("UNKNOWN verb: $mhs.");
        return;
    }

    # check if the arguments are too long to be stored in our table.
    my $toolong = 0;
    $toolong++ if ( length $lhs > $param{'maxKeySize'} );
    $toolong++ if ( length $rhs > $param{'maxDataSize'} );
    if ($toolong) {
        &performAddressedReply("that's too long");
        return 1;
    }

    # also checking.
    my $also = ( $rhs_utf8 =~ s/^-?also //i );
    my $also_or = ( $also and $rhs_utf8 =~ s/\s+(or|\|\|)\s+// );
    # update rhs and lhs
    $rhs = encode_utf8($rhs_utf8);
    $lhs = encode_utf8($lhs_utf8);

    if ( $also or $also_or ) {
        my $author = &getFactInfo( $from, 'created_by' );
        $author =~ /^(.*)!/;
        my $created_by = $1;

        # Can they even modify factoids?
        if (    &IsFlag('m') ne 'm'
            and &IsFlag('M') ne 'M'
            and &IsFlag('o') ne 'o' )
        {
            &performReply("You do not have permission to modify factoids");
            return 1;

            # If they have +M but they didnt create the factoid
        }
        elsif ( &IsFlag('M') eq 'M'
            and $who !~ /^\Q$created_by\E$/i
            and &IsFlag('m') ne 'm'
            and &IsFlag('o') ne 'o' )
        {
            &performReply("factoid '$lhs' is not yours to modify.");
            return 1;
        }
    }

    # factoid arguments handler.
    # must start with a non-variable
    if ( &IsChanConf('factoidArguments') > 0 and $lhs_utf8 =~ /^[^\$]+.*\$/ ) {
        &status("Update: Factoid Arguments found.");
        &status("Update: orig lhs => '$lhs'.");
        &status("Update: orig rhs => '$rhs'.");

        my @list;
        my $count = 0;
        $lhs_utf8 =~ s/^/cmd: /;
        while ( $lhs_utf8 =~ s/\$(\S+)/(.*?)/ ) {
            push( @list, "\$$1" );
            $count++;
            last if ( $count >= 10 );
        }

        if ( $count >= 10 ) {
            &msg( $who, "error: could not SAR properly." );
            &DEBUG("error: lhs => '$lhs' rhs => '$rhs'.");
            return;
        }

        my $z = join( ',', @list );
        $rhs_utf8 =~ s/^/($z): /;
	# update rhs and lhs
	$rhs = encode_utf8($rhs_utf8);
	$lhs = encode_utf8($lhs_utf8);

        &status("Update: new lhs => '$lhs' rhs => '$rhs'.");
    }

    # the fun begins.
    my $exists = &getFactoid($lhs);
    my $exists_utf8 = decode_utf8($exists);

    if ( !$exists ) {

        # nice 'are' hack (or work-around).
        if ( $mhs =~ /^are$/i and $rhs_utf8 !~ /<\S+>/ ) {
            &status("Update: 'are' hack detected.");
            $mhs = 'is';
            $rhs_utf8 = "<REPLY> are " . $rhs_utf8;
        }
	# update rhs and lhs
	$rhs = encode_utf8($rhs_utf8);
	$lhs = encode_utf8($lhs_utf8);

        &status("enter: <$who> \'$lhs\' =$mhs=> \'$rhs\'");
        $count{'Update'}++;

        &performAddressedReply('okay');

        &sqlInsert(
            'factoids',
            {
                created_by    => $nuh,
                created_time  => time(),    # modified time.
                factoid_key   => $lhs,
                factoid_value => $rhs,
            }
        );

        if ( !defined $rhs or $rhs eq '' ) {
            &ERROR("Update: rhs1 == NULL.");
        }

        return 1;
    }

    # factoid exists.
    if ( $exists eq $rhs ) {

        # this catches the following situation: (right or wrong?)
        #    "test is test"
        #    "test is also test"
        &performAddressedReply("i already had it that way");
        return 1;
    }

    if ($also) {    # 'is also'.
        my $redircount = 5;
        my $origlhs    = $lhs;
	my $origlhs_utf8 = $lhs_utf8;
        while ( $exists_utf8 =~ /^<REPLY> ?see (.*)/i ) {
            $redircount--;
            unless ($redircount) {
                &msg( $who, "$origlhs has too many levels of redirection." );
                return 1;
            }

            $lhs    = $1;
            $exists = &getFactoid($lhs);
            unless ($exists) {
                &msg( $who, "$1 is a dangling redirection." );
                return 1;
            }
	    $exists_utf8 = decode_utf8($exists);
        }

        if ($also_or) {    # 'is also ||'.
            $rhs_utf8 = $exists . ' || ' . $rhs_utf8;
	    $rhs = encode_utf8($rhs_utf8);
	    $lhs = encode_utf8($lhs_utf8);
        }
        else {

            #	    if ($exists =~ s/\,\s*$/,  /) {
            if ( $exists_utf8 =~ /\,\s*$/ ) {
                &DEBUG("current has trailing comma, just append as is");
                &DEBUG("Up: exists => $exists");
                &DEBUG("Up: rhs    => $rhs");

                # $rhs =~ s/^\s+//;
                # $rhs = $exists." ".$rhs;	# keep comma.
            }

            if ( $exists_utf8 =~ /\.\s*$/ ) {
                &DEBUG(
                    "current has trailing period, just append as is with 2 WS");
                &DEBUG("Up: exists => $exists");
                &DEBUG("Up: rhs    => $rhs");

                # $rhs =~ s/^\s+//;
                # use ucfirst();?
                # $rhs = $exists."  ".$rhs;	# keep comma.
            }

            if ( $rhs_utf8 =~ /^[A-Z]/ ) {
                if ( $rhs_utf8 =~ /\w+\s*$/ ) {
                    &status("auto insert period to factoid.");
                    $rhs_utf8 = $exists_utf8 . ". " . $rhs_utf8;
                }
                else {    # '?' or '.' assumed at end.
                    &status(
"orig factoid already had trailing symbol; not adding period."
                    );
                    $rhs_utf8 = $exists_utf8 . " " . $rhs_utf8;
                }
            }
            elsif ( $exists =~ /[\,\.\-]\s*$/ ) {
                &VERB(
"U: current has trailing symbols; inserting whitespace + new.",
                    2
                );
		$rhs_utf8 = $exists_utf8 . " " . $rhs_utf8;
            }
            elsif ( $rhs_utf8 =~ /^\./ ) {
                &VERB( "U: new text starts with period; appending directly", 2 );
		$rhs_utf8 = $exists_utf8 . $rhs_utf8;
            }
            else {
		$rhs_utf8 = $exists_utf8 . ', or ' . $rhs_utf8;
            }
	    $rhs = encode_utf8($rhs_utf8);
        }

        # max length check again.
        if ( length $rhs > $param{'maxDataSize'} ) {
            if ( length $rhs_utf8 > length $exists_utf8 ) {
                &performAddressedReply("that's too long");
                return 1;
            }
            else {
                &status(
"Update: new length is still longer than maxDataSize but less than before, we'll let it go."
                );
            }
        }
	$rhs = encode_utf8($rhs_utf8);
	$lhs = encode_utf8($lhs_utf8);
	$exists = encode_utf8($exists_utf8);

        &performAddressedReply('okay');

        $count{'Update'}++;
        &status("update: <$who> \'$lhs\' =$mhs=> \'$rhs\'; was \'$exists\'");
        &sqlSet(
            'factoids',
            { 'factoid_key' => $lhs },
            {
                modified_by   => $nuh,
                modified_time => time(),
                factoid_value => $rhs,
            }
        );

        if ( !defined $rhs or $rhs eq '' ) {
            &ERROR("Update: rhs1 == NULL.");
        }
    }
    else {    # not 'also'

        if ( !$correction_plausible ) {    # "no, blah is ..."
            if ($addressed) {
                &performStrictReply(
                    "...but \002$lhs\002 is already something else...");
                &status("FAILED update: <$who> \'$lhs\' =$mhs=> \'$rhs\'");
            }
            return 1;
        }

        my $author = &getFactInfo( $lhs, 'created_by' ) || '';

        if (   IsFlag('m') ne 'm'
            && IsFlag('o') ne 'o'
            && $author !~ /^\Q$who\E\!/i )
        {
            &msg( $who, "you can't change that factoid." );
            return 1;
        }

        &performAddressedReply('okay');

        $count{'Update'}++;
        &status("update: <$who> \'$lhs\' =$mhs=> \'$rhs\'; was \'$exists\'");

        &sqlSet(
            'factoids',
            { 'factoid_key' => $lhs },
            {
                modified_by   => $nuh,
                modified_time => time(),
                factoid_value => $rhs,
            }
        );

        if ( !defined $rhs or $rhs eq '' ) {
            &ERROR("Update: rhs1 == NULL.");
        }
    }

    return 1;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
