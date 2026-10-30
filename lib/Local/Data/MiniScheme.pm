package Local::Data::MiniScheme;

use 5.006;
use strict;
use warnings;
use parent qw(Exporter);

use IO::Handle;
use Scalar::Util qw(refaddr);
use Socket qw(LF);
use constant SX_NIL  => 1;
use constant SX_CONS => 2;
use constant SX_DOT  => 3;
use constant SX_SCALAR => 4;
use constant SX_SYMBOL => 5;

# nil is false (so `#f' works); everything else is true.
# '0+' keeps == comparing identity instead of truth values.
use overload
	'bool' => sub { $_[0]{tag} != SX_NIL },
	'0+'   => sub { refaddr $_[0] },
	fallback => 1;

our @EXPORT_OK = qw(nil cons str sym read_datum);

# state was introduced in v5.10
# until we pin that, this might be better...
BEGIN {
	my $nil =
		bless { tag => SX_NIL }, __PACKAGE__;

	sub nil ()
	{
		$nil;
	}
}

BEGIN {
	my $dot =
		bless { tag => SX_DOT }, __PACKAGE__;

	sub dot ()
	{
		$dot;
	}
}

sub cons ($$)
{
	bless {
		tag => SX_CONS,
		car => $_[0],
		cdr => $_[1],
	}, __PACKAGE__;
}

sub str ($)
{
	bless {
		tag => SX_SCALAR,
		value => $_[0],
	}, __PACKAGE__;
}

{
	my %tab;

	sub sym ($)
	{
		if (exists $tab{ $_[0] }) {
			return $tab{ $_[0] };
		}
		$tab{ $_[0] } = bless {
			tag => SX_SYMBOL,
			value => $_[0],
		}, __PACKAGE__;

	}
}

sub read_datum
{
	local $/;
	my ($fh, $bg) = @_;
	my ($v, $w);
	my $sb;
V:	while (defined( $v = $fh->getc() )) {
		if ($v =~ /[[:space:]]/) {
			next V;
		}
		if ($v eq ';') {
			$/ = LF;
			if (!defined $fh->getline()) {
				last V;
			}
			next V;
		}
		if ($v eq '.') {
			if (!defined( $w = $fh->getc() )) {
				$fh->error ? last V : return dot();
			}
			else {
				if ($w =~ /[[:space:]\(\)"\|;]/) {
					$fh->ungetc(ord $w);
					return dot();
				}
				if (defined( $w = read_plain($fh, $sb = "$v$w") )) {
					$fh->ungetc(ord $w);
				}
				return str($sb);
			}
		}
		if ($v eq '(') {
			my ($o, @q, $e);
			my $sg = 0;
			while (defined( $o = read_datum($fh, 1) )) {
				if ($sg == 0) {
					if ($o == dot()) {
						@q or die "read_datum: `.' too early\n";
						$sg++;
					} else {
						push @q, $o;
					}
				}
				elsif ($sg == 1) {
					if ($o == dot()) {
							die "read_datum: double `.'
";
						}
					push @q, $o;
					$sg++;
				}
				elsif ($sg == 2) {
					die "read_datum: too many tails\n";
				}
			}
			if ($sg == 0) {
				$e = nil();
			}
			elsif ($sg == 2) {
				$e = pop @q;
			}
			else {
				die "read_datum: `.' who?\n"
			}
			return !@q ? nil() : do {
				my $p = cons(pop @q, $e);
				while (@q) {
					$p = cons(pop @q, $p);
				}
				$p;
			};
		}
		if ($v eq ')') {
			$bg or die "read_datum: unexpected `)'\n";
			return;
		}
		$sb = "";
		if ($v eq '"') {
			$/ = '"';
P:			while (defined( $v = $fh->getc() )) {
				last P if $v eq '"';
				$v ne "\\" or die "read_datum: no escape plz :(\n";
				$sb .= $v;
			}
			last V if $fh->error;
			return str($sb);
		}
		if (defined( $w = read_plain($fh, $sb = "$v") )) {
			$fh->ungetc(ord $w);
		}
		return 1 if $sb eq '#t';
		return nil() if $sb eq '#f';
		return $v =~ /[[:digit:]]/ ? str($sb) : sym($sb);
	}
	!$fh->error or die "read_datum: read error\n";
	!$bg or die "read_datum: unterminated list\n";
	return;
}

sub read_plain
{
	my ($fh) = @_;
	my $sbp = \$_[1];
	my $v;

P:	while (defined( $v = $fh->getc() )) {
		if ($v =~ /[[:space:]\(\)"\|;]/) {
			last P;
		}
		$$sbp .= $v;
	}
	return $v;
}

1;
