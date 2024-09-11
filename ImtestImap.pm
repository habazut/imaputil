# A simple module for accessing an imap server through imtest (rather
# than the seriously broken perl library included with cyrus).
package ImtestImap;
use strict;
use FileHandle;
use IPC::Open2;
use POSIX qw(cuserid);

# Create a new imap connection.
# ($ref) = new ImtestImap($host)
#    $host : the host to connect to.
sub new {
    my $class = shift;
    my $self = { number => 10, debug => 0 };
    bless $self, $class;

#    $self->{debug} = 1;
    
    my ($host, $user) = @_;
    
    $host = $ENV{MAILHOST} unless defined $host;
    $host = 'imap' unless defined $host;
    
    $user = cuserid() unless defined $user;
    
    $self->{pid} = open2(*Reader, *Writer, "imtest -a $user $host") ||
	die "Failed to open imap connection: $!\n";
    return $self;
}

# Run a command through the imap connection
# ($result) = $ref->cmd($command, $save)
#     $command is the command to run (without the sequence id)
#     reply lines are stored in @$save, if defined
sub cmd {
    my ($self, $cmd, $save) = @_;
    ++$self->{number};
    $self->{debug} && print STDERR ">> $cmd\n";
    print Writer "$self->{number} $cmd\n"
	|| die "Failed to send command: $!\n";
    while(<Reader>) {
	last if /^$self->{number} /;
	push @$save, $_ if(defined $save);
	$self->{debug} && print STDERR "<< $_";
    }
    if(!defined) {
	die "Imap command $cmd failed: No response from server\n";
    
    } elsif(/^$self->{number} OK/) {	
	$self->{debug} && print STDERR "<. $_";
	return 1;
    } else {
	$self->{debug} && print STDERR "<. $_";
	return 0;
    }
}

# Run a command through the imap connection
# ($result) = $ref->cmd($command, $save)
#     $command is the command to run (without the sequence id)
#     $cb is called for each untagged status report
sub cmd_cb {
    my ($self, $cmd, $cb) = @_;
    ++$self->{number};
    $self->{debug} && print STDERR ">> $cmd\n";
    print Writer "$self->{number} $cmd\n"
	|| die "Failed to send command: $!\n";
    while(<Reader>) {
	if(/$self->{number} (OK|NO|BAD)/) {
	    $self->{debug} && print STDERR "<. $_";
	    return $1 eq 'OK';
	} 
	$self->{debug} && print STDERR "<< $_";
	&$cb($_);
    }
    $self->{debug} && print STDERR "End of data from imtest\n";
}

# Run a command through the imap connection
# ($result) = $ref->cmd($command, $save)
#     $cmd is the command to run (without the sequence id)
#     $data is aditional data to send to the server
sub cmd_data {
    my ($self, $cmd, $data) = @_;
    ++$self->{number};
    $self->{debug} && print STDERR ">> $cmd\n";
    print Writer "$self->{number} $cmd\n"
	|| die "Failed to send command: $!\n";
    while(<Reader>) {
	$self->{debug} && print STDERR "<< $_";
	if(/$self->{number} (OK|NO|BAD)/) {
	    $self->{debug} && print STDERR "<. $_";
	    return $1 eq 'OK';
	} 
	if (/^\+ /) {
	    $self->{debug} && print STDERR ">> $data";
	    print Writer $data;
	    print Writer "\r\n";
	}
#	&$cb($_);
    }
    $self->{debug} && print STDERR "End of data from imtest\n";
}

1;
