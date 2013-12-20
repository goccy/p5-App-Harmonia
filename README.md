# NAME

App::Harmonia - Generate model layer codes of your application for Parse.com

# SYNOPSIS

    use App::Harmonia;
    App::Harmonia->new({
        name             => 'your application name',
        application      => 'select application type',
        account          => 'your parse.com account',
        password         => 'your parse.com password',
        generate_dirname => 'directory name'
    })->run;

# DESCRIPTION

App::Harmonia generates model layer codes of your application for Parse.com.

# LICENSE

Copyright (C) Masaaki Goshima.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Masaaki Goshima <goccy54@gmail.com>
