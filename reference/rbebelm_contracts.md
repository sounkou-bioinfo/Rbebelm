# Rbebelm agent framework contracts

These S7/s7contract interfaces keep the loop, extension, skill, and
prompt infrastructure independent from the concrete LLM backend. BebeLM
implements `BebelAgentBackend`; other local or remote providers can
implement the same generics later.
