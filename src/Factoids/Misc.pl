#
#   Misc.pl: Miscellaneous stuff.
#    Author: dms
#   Version: v0.1 (20010906)
#   Created: 20010906
#

if (&IsParam("useStrict")) { use strict; }

# Usage: &validFactoid($lhs,$rhs);
sub validFactoid {
    my ($lhs,$rhs) = @_;
    my $valid = 0;

    for (lc $lhs) {
	# allow the following only if they have been made on purpose.
	if ($rhs ne "" and $rhs !~ /^</) {
	    / \Q$ident$/i and last;	# someone said i'm something.
	    /^i('m)? / and last;
	    /^(it|that|there|what)('s)?(\s+|$)/ and last;
	    /^you('re)?(\s+|$)/ and last;

	    /^(where|who|why|when|how)(\s+|$)/ and last;
	    /^(this|that|these|those|they)(\s+|$)/ and last;
	    /^(every(one|body)|we) / and last;

	    /^say / and last;
	}

	# uncaught commands.
	/^add topic / and last;		# topic management.
	/( add$| add |^add )/ and last;	# borked teach statement.
	/^learn / and last;		# teach. damn morons.
	/^tell (\S+) about / and last;	# tell.
	/\=\~/ and last;		# substituition.
	/^\S+ to \S+ \S+/ and last;	# babelfish.

	/^\=/ and last;			# botnick = heh is.
	/wants you to know/ and last;

	# symbols.
	/(\"\*)/ and last;
	/, / and last;
	(/^'/ and /'$/) and last;
	(/^"/ and /"$/) and last;

	# delimiters.
	/\=\>/ and last;		# '=>'.
	/\;\;/ and last;		# ';;'.
	/\|\|/ and last;		# '||'.

	/^\Q$ident\E[\'\,\: ]/ and last;# dupe addressed.
	/^[\-\, ]/ and last;
	/\\$/ and last;			# forgot shift for '?'.
	/^all / and last;
	/^also / and last;
	/ also$/ and last;
	/ and$/ and last;
	/^because / and last;
	/^but / and last;
	/^gives / and last;
	/^h(is|er) / and last;
	/^if / and last;
	/ is,/ and last;
	/ it$/ and last;
	/^or / and last;
	/ says$/ and last;
	/^should / and last;
	/^so / and last;
	/^supposedly/ and last;
	/^to / and last;
	/^was / and last;
	/ which$/ and last;

	# nasty bug I introduced _somehow_, probably by fixMySQLBug().
	/\\\%/ and last;
	/\\\_/ and last;

	# weird/special stuff. also old blootbot or stock infobot bugs.
	$rhs =~ /( \Q$ident\E's|\Q$ident\E's )/i and last; # ownership.

	# duplication.
	$rhs =~ /^\Q$lhs /i and last;
	last if ($rhs =~ /^is /i and / is$/);

	$valid++;
    }

    return $valid;
}

sub FactoidStuff {
    # inter-infobot.
    if ($msgType =~ /private/ and $message =~ s/^:INFOBOT://) {
	### identification.
	&status("infobot <$nuh> identified") unless $bots{$nuh};
	$bots{$nuh} = $who;

	### communication.

	# query.
	if ($message =~ /^QUERY (<.*?>) (.*)/) {	# query.
	    my ($target,$item) = ($1,$2);
	    $item =~ s/[.\?]$//;

	    &status(":INFOBOT:QUERY $who: $message");

	    if ($_ = &getFactoid($item)) {
		&msg($who, ":INFOBOT:REPLY $target $item =is=> $_");
	    }

	    return 'INFOBOT QUERY';
	} elsif ($message =~ /^REPLY <(.*?)> (.*)/) {	# reply.
	    my ($target,$item) = ($1,$2);

	    &status(":INFOBOT:REPLY $who: $message");

	    my ($lhs,$mhs,$rhs) = $item =~ /^(.*?) =(.*?)=> (.*)/;

	    if ($param{'acceptUrl'} !~ /REQUIRE/ or $rhs =~ /(http|ftp|mailto|telnet|file):/) {
		&msg($target, "$who knew: $lhs $mhs $rhs");

		# "are" hack :)
		$rhs = "<REPLY> are" if ($mhs eq "are");
		&setFactInfo($lhs, "factoid_value", $rhs);
	    }

	    return 'INFOBOT REPLY';
	} else {
	    &ERROR(":INFOBOT:UNKNOWN $who: $message");
	    return 'INFOBOT UNKNOWN';
	}
    }

    # factoid forget.
    if ($message =~ s/^forget\s+//i) {
	return 'forget: no addr' unless ($addressed);

	my $faqtoid = $message;
	if ($faqtoid eq "") {
	    &help("forget");
	    return;
	}

	$faqtoid =~ tr/A-Z/a-z/;
	my $result = &getFactoid($faqtoid);

	if (defined $result) {
	    my $author	= &getFactInfo($faqtoid, "created_by");
	    my $count	= &getFactInfo($faqtoid, "requested_count") || 0;
	    my $limit	= &getChanConfDefault("factoidPreventForgetLimit", 
				0, $chan);

	    &DEBUG("forget: limit = $limit");
	    &DEBUG("forget: count = $count");

	    if (IsFlag("r") ne "r") {
		&msg($who, "you don't have access to remove factoids");
		return;
	    }

	    return 'locked factoid' if (&IsLocked($faqtoid) == 1);

	    # factoidPreventForgetLimit:
	    if ($limit and $count > $limit and (&IsFlag("o") ne "o")) {
		&msg($who, "will not delete '$faqtoid', count > limit ($count > $limit)");
		return;
	    }

	    if (&IsParam("factoidDeleteDelay") or &IsChanConf("factoidDeleteDelay")) {
		if ($faqtoid =~ / #DEL#$/ and !&IsFlag("o")) {
		    &msg($who, "cannot delete it ($faqtoid).");
		    return;
		}

		&status("forgot (safe delete): <$who> '$faqtoid' =is=> '$result'");
		### TODO: check if the "backup" exists and overwrite it
		my $check = &getFactoid("$faqtoid #DEL#");

		if (!defined $check or $check =~ /^\s*$/) {
		    if ($faqtoid !~ / #DEL#$/) {
			my $new = $faqtoid." #DEL#";

			my $backup = &getFactoid($faqtoid);
			# this looks weird but does it work?
			if ($backup) {
			    &DEBUG("forget: not overwriting backup: $faqtoid");
			} else {
			    &status("forget: backing up '$faqtoid'");
			    &setFactInfo($faqtoid, "factoid_key", $new);
			    &setFactInfo($new, "modified_by", $who);
			    &setFactInfo($new, "modified_time", time());
			}

		    } else {
			&status("forget: not backing up $faqtoid.");
		    }

		} else {
		    &status("forget: not overwriting backup!");
		}

	    } else {
		&status("forget: <$who> '$faqtoid' =is=> '$result'");
	    }
	    &delFactoid($faqtoid);

	    &performReply("i forgot $faqtoid");

	    $count{'Update'}++;
	} else {
	    &performReply("i didn't have anything called '$faqtoid'");
	}

	return;
    }

    # factoid unforget/undelete.
    if ($message =~ s/^un(forget|delete)\s+//i) {
	return 'unforget: no addr' unless ($addressed);

	my $i = 0;
	$i++ if (&IsParam("factoidDeleteDelay"));
	$i++ if (&IsChanConf("factoidDeleteDelay"));
	if (!$i) {
	    &performReply("safe delete has been disable so what is there to undelete?");
	    return;
	}

	my $faqtoid = $message;
	if ($faqtoid eq "") {
	    &help("undelete");
	    return;
	}

	$faqtoid =~ tr/A-Z/a-z/;
	my $result = &getFactoid($faqtoid." #DEL#");
	my $check  = &getFactoid($faqtoid);

	if (!defined $result) {
	    &performReply("i didn't have anything ('$faqtoid') to undelete.");
	    return;
	}

	if (defined $check) {
	    &performReply("cannot undeleted '$faqtoid' because it already exists?");
	    return;
	}

	&setFactInfo($faqtoid." #DEL#", "factoid_key", $faqtoid);

	### delete info. modified_ isn't really used.
	&setFactInfo($faqtoid, "modified_by",  "");
	&setFactInfo($faqtoid, "modified_time", 0);

	&performReply("Successfully recovered '$faqtoid'.  Have fun now.");

	$count{'Undelete'}++;

	return;
    }

    # factoid locking.
    if ($message =~ /^((un)?lock)(\s+(.*))?\s*?$/i) {
	return 'lock: no addr 2' unless ($addressed);

	my $function = lc $1;
	my $faqtoid  = lc $4;

	if ($faqtoid eq "") {
	    &help($function);
	    return;
	}

	if (&getFactoid($faqtoid) eq "") {
	    &msg($who, "factoid \002$faqtoid\002 does not exist");
	    return;
	}

	if ($function eq "lock") {
	    # strongly requested by #debian on 19991028. -xk
	    if (1 and $faqtoid !~ /^\Q$who\E$/i and &IsFlag("o") ne "o") {
		&msg($who,"sorry, locking cannot be used since it can be abused unneccesarily.");
		&status("Replace 1 with 0 in Process.pl#~324 for locking support.");
		return;
	    }

	    &CmdLock($faqtoid);
	} else {
	    &CmdUnLock($faqtoid);
	}

	return;
    }

    # factoid rename.
    if ($message =~ s/^rename(\s+|$)//) {
	return 'rename: no addr' unless ($addressed);

	if ($message eq "") {
	    &help("rename");
	    return;
	}

	if ($message =~ /^'(.*)'\s+'(.*)'$/) {
	    my($from,$to) = (lc $1, lc $2);

	    my $result = &getFactoid($from);
	    if (defined $result) {
		my $author = &getFactInfo($from, "created_by");

		if (&IsFlag("m") or $author =~ /^\Q$who\E\!/i) {
		    &msg($who, "It's not yours to modify.");
		    return;
		}

		if ($_ = &getFactoid($to)) {
		    &performReply("destination factoid already exists.");
		    return;
		}

		&setFactInfo($from,"factoid_key",$to);

		&status("rename: <$who> '$from' is now '$to'");
		&performReply("i renamed '$from' to '$to'");
	    } else {
		&performReply("i didn't have anything called '$from'");
	    }
	} else {
	    &msg($who,"error: wrong format. ask me about 'help rename'.");
	}

	return;
    }

    # factoid substitution. (X =~ s/A/B/FLAG)
    if ($message =~ m|^(.*?)\s+=~\s+s([/,#])(.+?)\2(.*?)\2([a-z]*);?\s*$|) {
	my ($faqtoid,$delim,$op,$np,$flags) = (lc $1, $2, $3, $4, $5);
	return 'subst: no addr' unless ($addressed);

	# incorrect format.
	if ($np =~ /$delim/) {
	    &msg($who,"looks like you used the delimiter too many times. You may want to use a different delimiter, like ':' or '#'.");
	    return;
	}

	# success.
	if (my $result = &getFactoid($faqtoid)) {
	    return 'subst: locked' if (&IsLocked($faqtoid) == 1);
	    my $was = $result;

	    if (($flags eq "g" && $result =~ s/\Q$op/$np/gi) || $result =~ s/\Q$op/$np/i) {
		if (length $result > $param{'maxDataSize'}) {
		    &performReply("that's too long");
		    return;
		}
		&setFactInfo($faqtoid, "factoid_value", $result);
		&status("update: '$faqtoid' =is=> '$result'; was '$was'");
		&performReply("OK");
	    } else {
		&performReply("that doesn't contain '$op'");
	    }
	} else {
	    &performReply("i didn't have anything called '$faqtoid'");
	}

	return;
    }

    # Fix up $message for question.
    my $question = $message;
    for ($question) {
	# fix the string.
	s/^hey([, ]+)where/where/i;
	s/\s+\?$/?/;
	s/whois/who is/ig;
	s/where can i find/where is/i;
	s/how about/where is/i;
	s/ da / the /ig;

	# clear the string of useless words.
	s/^(stupid )?q(uestion)?:\s+//i;
	s/^(does )?(any|ne)(1|one|body) know //i;

	s/^[uh]+m*[,\.]* +//i;

	s/^well([, ]+)//i;
	s/^still([, ]+)//i;
	s/^(gee|boy|golly|gosh)([, ]+)//i;
	s/^(well|and|but|or|yes)([, ]+)//i;

	s/^o+[hk]+(a+y+)?([,. ]+)//i;
	s/^g(eez|osh|olly)([,. ]+)//i;
	s/^w(ow|hee|o+ho+)([,. ]+)//i;
	s/^heya?,?( folks)?([,. ]+)//i;
    }

    if ($addressed and $message =~ s/^no([, ]+)(\Q$ident\E\,+)?\s*//i) {
	$correction_plausible = 1;
	&status("correction is plausible, initial negative and nick deleted ($&)") if ($param{VERBOSITY});
    } else {
	$correction_plausible = 0;
    }

    my $result = &doQuestion($question);
    if (!defined $result or $result eq $noreply) {
	return 'result from doQ undef.';
    }

    if (defined $result and $result !~ /^0?$/) {	# question.
	&status("question: <$who> $message");
	$count{'Question'}++;
    } elsif (&IsChanConf("perlMath") > 0 and $addressed) { # perl math.
	&loadMyModule("perlMath");
	my $newresult = &perlMath();

	if (defined $newresult and $newresult ne "") {
	    $cmdstats{'Maths'}++;
	    $result = $newresult;
	    &status("math: <$who> $message => $result");
	}
    }

    if ($result !~ /^0?$/) {
	&performStrictReply($result);
	return;
    }

    # why would a friendly bot get passed here?
    if (&IsParam("friendlyBots")) {
	return if (grep lc($_) eq lc($who), split(/\s+/, $param{'friendlyBots'}));
    }

    # do the statement.
    if (!defined &doStatement($message)) {
	return;
    }

    return unless ($addressed);

    if (length $message > 64) {
	&status("unparseable-moron: $message");
#	&performReply( &getRandom(keys %{ $lang{'moron'} }) );
	$count{'Moron'}++;

	&performReply("You are moron \002#". $count{'Moron'} ."\002");
	return;
    }

    &status("unparseable: $message");
    &performReply( &getRandom(keys %{ $lang{'dunno'} }) );
    $count{'Dunno'}++;
}

1;
