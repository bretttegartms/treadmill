"""Installs and configures Treadmill locally.
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

import logging
import os

import click

from treadmill import bootstrap
from treadmill import cli
from treadmill import context


_LOGGER = logging.getLogger(__name__)


def init():
    """Return top level command handler."""

    @click.command()
    @click.option('--gssapi', help='use gssapi auth.', is_flag=True,
                  default=False)
    @click.option('-p', '--rootpw',
                  help='password hash, generated by slappass -s <pwd>.')
    @click.option('-o', '--owner', help='root user.', required=True)
    @click.option('--env', help='Treadmill environment',
                  required=True, envvar='TREADMILL_ENV')
    @click.option('-s', '--suffix',
                  help='suffix (e.g dc=example,dc=com).',
                  required=False)
    @click.option('-u', '--uri', help='uri, e.g: ldap://...:20389',
                  required=True)
    @click.option('-m', '--masters', help='list of masters.',
                  type=cli.LIST)
    @click.option('--first-time/--no-first-time', is_flag=True, default=False)
    @click.option('--run/--no-run', is_flag=True, default=False)
    @click.pass_context
    def openldap(ctx, gssapi, rootpw, owner, suffix, uri, masters,
                 first_time, run, env):
        """Installs Treadmill Openldap server."""
        dst_dir = ctx.obj['PARAMS']['dir']
        profile = ctx.obj['PARAMS'].get('profile')

        run_script = None
        if run:
            run_script = os.path.join(dst_dir, 'bin', 'run.sh')

        ctx.obj['PARAMS']['env'] = env
        ctx.obj['PARAMS']['treadmillid'] = owner
        ctx.obj['PARAMS']['owner'] = owner

        if uri:
            ctx.obj['PARAMS']['uri'] = uri
            if masters and uri in masters:
                ctx.obj['PARAMS']['is_master'] = True
        if rootpw:
            ctx.obj['PARAMS']['rootpw'] = rootpw
        if gssapi:
            ctx.obj['PARAMS']['gssapi'] = gssapi
            ctx.obj['PARAMS']['rootpw'] = ''
        if masters:
            ctx.obj['PARAMS']['masters'] = masters
        else:
            ctx.obj['PARAMS']['masters'] = []

        if first_time:
            ctx.obj['PARAMS']['first_time'] = first_time

        if suffix:
            ctx.obj['PARAMS']['suffix'] = suffix
        else:
            ctx.obj['PARAMS']['suffix'] = context.GLOBAL.ldap_suffix

        bootstrap.install(
            'openldap',
            dst_dir,
            ctx.obj['PARAMS'],
            run=run_script,
            profile=profile,
        )

    return openldap
