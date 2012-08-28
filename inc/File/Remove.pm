#line 1
package File::Remove;

use 5.00503;
use strict;

use vars qw{ $VERSION @ISA @EXPORT_OK };
use vars qw{ $DEBUG $unlink $rmdir    };
BEGIN {
	$VERSION   = '1.49';
	# $VERSION   = eval $VERSION;
	@ISA       = qw{ Exporter };
	@EXPORT_OK = qw{ remove rm clear trash };
}

# If we ever need a Mac::Glue object we will want to cache it.
my $glue;

use File::Path ();
use File::Glob ();
use File::Spec 3.2701 ();
use Cwd        3.2701 ();

sub expand (@) {
	map { -e $_ ? $_ : File::Glob::bsd_glob($_) } @_;
}

# $debug variable must be set before loading File::Remove.
# Convert to a constant to allow debugging code to be pruned out.
use constant DEBUG    => !! $DEBUG;

# Are we on VMS?
# If so copy File::Path and assume VMS::Filespec is loaded
use constant IS_VMS   => !! ( $^O eq 'VMS' );

# Are we on Mac?
# If so we'll need to do some special trash work
use constant IS_MAC   => !! ( $^O eq 'darwin' );

# Are we on Win32?
# If so write permissions does not imply deletion permissions
use constant IS_WIN32 => !! ( $^O =~ /^MSWin/ or $^O eq 'cygwin' );





#####################################################################
# Main Functions

my @END_DELETE = ();

sub clear (@) {
	my @files = expand( @_ );

	# Do the initial deletion
	foreach my $file ( @files ) {
		next unless -e $file;
		remove( \1, $file );
	}

	# Delete again at END-time
	push @END_DELETE, @files;
}

END {
	foreach my $file ( @END_DELETE ) {
		next unless -e $file;
		remove( \1, $file );
	}
}

# acts like unlink would until given a directory as an argument, then
# it acts like rm -rf ;) unless the recursive arg is zero which it is by
# default
sub remove (@) {
	my $recursive = (ref $_[0] eq 'SCALAR') ? shift : \0;
	my @files     = expand(@_);

	# Iterate over the files
	my @removes;
	foreach my $path ( @files ) {
		# need to check for symlink first
		# could be pointing to nonexisting/non-readable destination
		if ( -l $path ) {
			print "link: $path\n" if DEBUG;
			if ( $unlink ? $unlink->($path) : unlink($path) ) {
				push @removes, $path;
			}
			next;
		}
		unless ( -e $path ) {
			print "missing: $path\n" if DEBUG;
			push @removes, $path; # Say we deleted it
			next;
		}
		my $can_delete;
		if ( IS_VMS ) {
			$can_delete = VMS::Filespec::candelete($path);
		} elsif ( IS_WIN32 ) {
			# Assume we can delete it for the moment
			$can_delete = 1;
		} elsif ( -w $path ) {
			# We have write permissions already
			$can_delete = 1;
		} elsif ( $< == 0 ) {
			# Unixy and root
			$can_delete = 1;
		} elsif ( (lstat($path))[4] == $< ) {
			# I own the file
			$can_delete = 1;
		} else {
			# I don't think we can delete it
			$can_delete = 0;
		}
		unless ( $can_delete ) {
			print "nowrite: $path\n" if DEBUG;
			next;
		}

		if ( -f $path ) {
			print "file: $path\n" if DEBUG;
			unless ( -w $path ) {
				# Make the file writable (implementation from File::Path)
				(undef, undef, my $rp) = lstat $path or next;
				$rp &= 07777; # Don't forget setuid, setgid, sticky bits
				$rp |= 0600;  # Turn on user read/write
				chmod $rp, $path;
			}
			if ( $unlink ? $unlink->($path) : unlink($path) ) {
				# Failed to delete the file
				next if -e $path;
				push @removes, $path;
			}

		} elsif ( -d $path ) {
			print "dir: $path\n" if DEBUG;
			my $dir = File::Spec->canonpath($path);

			# Do we need to move our cwd out of the location
			# we are planning to delete?
			my $chdir = _moveto($dir);
			if ( length $chdir ) {
				chdir($chdir) or next;
			}

			if ( $$recursive ) {
				if ( File::Path::rmtree( [ $dir ], DEBUG, 0 ) ) {
					# Failed to delete the directory
					next if -e $path;
					push @removes, $path;
				}

			} else {
				my ($save_mode) = (stat $dir)[2];
				chmod $save_mode & 0777, $dir; # just in case we cannot remove it.
				if ( $rmdir ? $rmdir->($dir) : rmdir($dir) ) {
					# Failed to delete the directory
					next if -e $path;
					push @removes, $path;
				}
			}

		} else {
			print "???: $path\n" if DEBUG;
		}
	}

	return @removes;
}

sub rm (@) {
	goto &remove;
}

sub trash (@) {
	local $unlink = $unlink;
	local $rmdir  = $rmdir;

	if ( ref $_[0] eq 'HASH' ) {
		my %options = %{+shift @_};
		$unlink = $options{unlink};
		$rmdir  = $options{rmdir};

	} elsif ( IS_WIN32 ) {
		local $@;
		eval 'use Win32::FileOp ();';
		die "Can't load Win32::FileOp to support the Recycle Bin: \$@ = $@" if length $@;
		$unlink = \&Win32::FileOp::Recycle;
		$rmdir  = \&Win32::FileOp::Recycle;

	} elsif ( IS_MAC ) {
		unless ( $glue ) {
			local $@;
			eval 'use Mac::Glue ();';
			die "Can't load Mac::Glue::Finder to support the Trash Can: \$@ = $@" if length $@;
			$glue = Mac::Glue->new('Finder');
		}
		my $code = sub {
			my @files = map {
				Mac::Glue::param_type(
					Mac::Glue::typeAlias() => $_
				)
			} @_;
			$glue->delete(\@files);
		};
		$unlink = $code;
		$rmdir  = $code;
	} else {
		die "Support for trash() on platform '$^O' not available at this time.\n";
	}

	remove(@_);
}

sub undelete (@) {
	goto &trash;
}





######################################################################
# Support Functions

# Do we need to move to a different directory to delete a directory,
# and if so which.
sub _moveto {
	my $remove = File::Spec->rel2abs(shift);
	my $cwd    = @_ ? shift : Cwd::cwd();

	# Do everything in absolute terms
	$remove = Cwd::abs_path( $remove );
	$cwd    = Cwd::abs_path( $cwd    );

	# If we are on a different volume we don't need to move
	my ( $cv, $cd ) = File::Spec->splitpath( $cwd,    1 );
	my ( $rv, $rd ) = File::Spec->splitpath( $remove, 1 );
	return '' unless $cv eq $rv;

	# If we have to move, it's to one level above the deletion
	my @cd = File::Spec->splitdir($cd);
	my @rd = File::Spec->splitdir($rd);

	# Is the current directory the same as or inside the remove directory?
	unless ( @cd >= @rd ) {
		return '';
	}
	foreach ( 0 .. $#rd ) {
		$cd[$_] eq $rd[$_] or return '';
	}

	# Confirmed, the current working dir is in the removal dir
	pop @rd;
	return File::Spec->catpath(
		$rv,
		File::Spec->catdir(@rd),
		''
	);
}

1;

__END__

#line 382
