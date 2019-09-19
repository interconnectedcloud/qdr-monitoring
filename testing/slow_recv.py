#!/usr/bin/env python
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

import optparse
from proton.handlers import MessagingHandler
from proton.reactor import Container

class TimedFlow(MessagingHandler):
    def __init__(self, receiver, credit):
        super(TimedFlow, self).__init__()
        self.receiver = receiver
        self.credit = credit

    def on_timer_task(self, event):
        self.receiver.flow(self.credit)

class Recv(MessagingHandler):
    def __init__(self, url, count, rate):
        super(Recv, self).__init__(prefetch=0)
        self.url = url
        self.expected = count
        self.received = 0
        self.batch_size = rate

    def on_start(self, event):
        event.container.create_receiver(self.url)

    def request_batch(self, event):
        event.container.schedule(1, TimedFlow(event.receiver, self.batch_size))

    def on_link_opened(self, event):
        self.request_batch(event)

    def check_empty(self, receiver):
        return not receiver.credit and not receiver.queued

    def on_link_flow(self, event):
        if self.check_empty(event.receiver):
            self.request_batch(event)

    def on_message(self, event):
        if self.expected == 0 or self.received < self.expected:
            print event.message.body
            self.received += 1
            if self.received == self.expected:
                event.receiver.close()
                event.connection.close()
        if self.check_empty(event.receiver):
            self.request_batch(event)


parser = optparse.OptionParser(usage="usage: %prog [options]")
parser.add_option("-a", "--address", default="localhost:5672/examples",
                  help="address from which messages are received (default %default)")
parser.add_option("-m", "--messages", type="int", default=0,
                  help="number of messages to receive; 0 receives indefinitely (default %default)")
parser.add_option("-r", "--rate", type="int", default=10,
                  help="desired message rate in messages per second (default %default)")
opts, args = parser.parse_args()

try:
    Container(Recv(opts.address, opts.messages, opts.rate)).run()
except KeyboardInterrupt: pass



