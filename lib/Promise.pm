package Promise;
use Mojo::Base -base;
use experimental 'signatures';

use Carp;
use Try::Tiny;

our $PENDING   = 'pending';
our $FULFILLED = 'fulfilled';
our $REJECTED  = 'rejected';

has _handlers => sub { [] };
has _state    => $PENDING;
has _value    => undef;

sub new {
    my $self = shift->SUPER::new;
    my $fn = shift // sub { };
    _resolve($fn, sub { $self->resolve(@_) }, sub { $self->reject(@_) });
    return $self;
}

sub _resolve($fn, $on_ful_filled, $on_rejected) {
    my $done = 0;
    try {
        $fn->(
            sub($value) {
                return if $done;
                $done = 1;
                $on_ful_filled->($value);
            },
            sub ($reason) {
                return if $done;
                $done = 2;
                $on_rejected->($reason);
            }
        );
    }
    catch {
        return if $done;
        $done = 1;
        $on_rejected->($_);
    }
}

sub _get_then($self, $value) {
    my $t = ref($value);
    if ($value && ($t eq 'HASH' || $t eq 'CODE')) {
        if (my $then = $value->can('then')) {
            return $then;
        }
    }
    return;
}

sub fullfill($self, $result) {
    $self->_state($FULFILLED);
    $self->_value($result);
    for my $handler (@{$self->_handlers}) {
        $self->handle($handler);
    }
    $self->_handlers([]);
    return $self;
}

sub reject($self, $reason) {
    $self->_state('rejected');
    $self->_value($reason);
    for my $handler (@{$self->_handlers}) {
        $self->handle($handler);
    }
    $self->_handlers([]);
    return $self;
}

sub resolve($self, $value) {
    $self->_state('fulfilled');
    $self->_value($value);
    for my $handler (@{$self->_handlers}) {
        $self->handle($handler);
    }

    try {
        my $then = $self->_get_then($value);
        if ($then) {
            _resolve($then, $self->can('resolve'), $self->can('reject'));
            return;
        }
        $self->fullfill($value);
    }
    catch { $self->reject($_) };

    return $self;
}

sub handle($self, $handler) {
    my $state = $self->_state;
    if ($state eq $PENDING) {
        push @{$self->_handlers}, $handler;
    }
    else {
        if ($state eq $FULFILLED && ref($handler->{on_ful_filled})) {
            $handler->{on_ful_filled}->($self->_value);
        }
        if ($state eq $REJECTED && ref($handler->{on_rejected})) {
            $handler->{on_rejected}->($self->_value);
        }
    }
    return $self;
}

sub done($self, $on_ful_filled = undef, $on_rejected = undef) {
    $self->handle(
        {on_ful_filled => $on_ful_filled, on_rejected => $on_rejected});
    return $self;
}

sub then($self, $on_ful_filled = undef, $on_rejected = undef) {
    return Promise->new(
        sub ($resolve, $reject) {
            return $self->done(
                sub ($result) {
                    if (ref($on_ful_filled) eq 'CODE') {
                        try {
                            return $self->resolve($on_ful_filled->($result));
                        }
                        catch {
                            return $self->resolve($result)
                        };
                    }
                },
                sub ($error) {
                    if (ref($on_rejected) eq 'CODE') {
                        try {
                            return $self->resolve($on_rejected->($error));
                        }
                        catch { return $self->reject($_) };
                    }
                    else {
                        return $self->reject($error);
                    }
                }
            );
        }
    );
}

1;
