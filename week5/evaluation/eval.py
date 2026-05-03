import sys
import math
import time
import asyncio
import hashlib
import json
from functools import lru_cache

from pydantic import BaseModel, Field
from litellm import completion, acompletion
from dotenv import load_dotenv

from evaluation.test import TestQuestion, load_tests
from pro_implementation.answer import answer_question, fetch_context

load_dotenv(override=True)

MODEL = "openai/gpt-5.4-mini"
#MODEL = "openai/gpt-5.4-nano"
MAX_CONCURRENT = 3        # control parallelism
TIMEOUT_SECONDS = 30      # prevent hanging calls


# =========================
# Models (UNCHANGED)
# =========================

class RetrievalEval(BaseModel):
    mrr: float
    ndcg: float
    keywords_found: int
    total_keywords: int
    keyword_coverage: float


class AnswerEval(BaseModel):
    feedback: str
    accuracy: float
    completeness: float
    relevance: float


# =========================
# CACHING
# =========================

@lru_cache(maxsize=1000)
def cached_fetch_context(question: str):
    return fetch_context(question)


def _hash_key(*args):
    return hashlib.md5(json.dumps(args, sort_keys=True).encode()).hexdigest()


_eval_cache = {}


# =========================
# RETRIEVAL METRICS
# =========================

def calculate_mrr(keyword: str, retrieved_docs: list) -> float:
    keyword_lower = keyword.lower()
    for rank, doc in enumerate(retrieved_docs, start=1):
        if keyword_lower in doc.page_content.lower():
            return 1.0 / rank
    return 0.0


def calculate_dcg(relevances: list[int], k: int) -> float:
    return sum(rel / math.log2(i + 2) for i, rel in enumerate(relevances[:k]))


def calculate_ndcg(keyword: str, retrieved_docs: list, k: int = 10) -> float:
    keyword_lower = keyword.lower()

    relevances = [
        1 if keyword_lower in doc.page_content.lower() else 0
        for doc in retrieved_docs[:k]
    ]

    dcg = calculate_dcg(relevances, k)
    idcg = calculate_dcg(sorted(relevances, reverse=True), k)

    return dcg / idcg if idcg > 0 else 0.0


def evaluate_retrieval(test: TestQuestion, k: int = 10) -> RetrievalEval:
    start = time.time()

    retrieved_docs = cached_fetch_context(test.question)[:k]

    mrr_scores = [
        calculate_mrr(keyword, retrieved_docs)
        for keyword in test.keywords
    ]

    ndcg_scores = [
        calculate_ndcg(keyword, retrieved_docs, k)
        for keyword in test.keywords
    ]

    keywords_found = sum(1 for s in mrr_scores if s > 0)

    print(f"⏱ Retrieval eval took {time.time() - start:.2f}s")

    return RetrievalEval(
        mrr=sum(mrr_scores) / len(mrr_scores) if mrr_scores else 0,
        ndcg=sum(ndcg_scores) / len(ndcg_scores) if ndcg_scores else 0,
        keywords_found=keywords_found,
        total_keywords=len(test.keywords),
        keyword_coverage=(keywords_found / len(test.keywords) * 100)
        if test.keywords else 0,
    )


# =========================
# SAFE ASYNC WRAPPERS
# =========================

async def _run_with_timeout(func, *args):
    loop = asyncio.get_event_loop()
    return await asyncio.wait_for(
        loop.run_in_executor(None, func, *args),
        timeout=TIMEOUT_SECONDS
    )


# =========================
# ANSWER EVALUATION
# =========================

def evaluate_answer(test: TestQuestion) -> tuple[AnswerEval, str, list]:
    start_total = time.time()

    # ---- Generate answer ----
    start = time.time()
    generated_answer, retrieved_docs = answer_question(test.question)
    print(f"⏱ answer_question: {time.time() - start:.2f}s")

    # ---- Cache check ----
    key = _hash_key(test.question, generated_answer, test.reference_answer)

    if key in _eval_cache:
        print("⚡ Cache hit (judge)")
        return _eval_cache[key], generated_answer, retrieved_docs

    # ---- Judge ----
    start = time.time()

    judge_prompt = f"""
Q: {test.question}
A: {generated_answer}
R: {test.reference_answer}

Score:
- accuracy (1-5, wrong=1)
- completeness (1-5)
- relevance (1-5)

Return JSON with:
feedback, accuracy, completeness, relevance
"""

    response = completion(
        model=MODEL,
        messages=[
            {"role": "system", "content": "Evaluate answer quality."},
            {"role": "user", "content": judge_prompt},
        ],
        max_retries=0,
    )

    try:
        parsed = json.loads(response.choices[0].message.content)
        result = AnswerEval(**parsed)
    except Exception:
        print("⚠️ JSON parse failed, fallback scoring")
        result = AnswerEval(
            feedback="Parsing failed",
            accuracy=1,
            completeness=1,
            relevance=1,
        )

    print(f"⏱ judge: {time.time() - start:.2f}s")
    print(f"⏱ TOTAL test time: {time.time() - start_total:.2f}s")

    _eval_cache[key] = result

    return result, generated_answer, retrieved_docs


# =========================
# PARALLEL EXECUTION (CONTROLLED)
# =========================

async def _evaluate_single(test, sem):
    async with sem:
        return await _run_with_timeout(evaluate_answer, test)


def evaluate_all_answers():
    tests = load_tests()
    total = len(tests)

    async def runner():
        sem = asyncio.Semaphore(MAX_CONCURRENT)
        tasks = [_evaluate_single(t, sem) for t in tests]
        return await asyncio.gather(*tasks, return_exceptions=True)

    results = asyncio.run(runner())

    for i, (test, res) in enumerate(zip(tests, results)):
        progress = (i + 1) / total

        if isinstance(res, Exception):
            print(f"❌ Error in test {i}: {res}")
            continue

        yield test, res[0], progress


def evaluate_all_retrieval():
    tests = load_tests()
    total = len(tests)

    for i, test in enumerate(tests):
        result = evaluate_retrieval(test)
        yield test, result, (i + 1) / total


# =========================
# CLI
# =========================

def run_cli_evaluation(test_number: int):
    tests = load_tests("tests.jsonl")

    if test_number < 0 or test_number >= len(tests):
        print(f"Error: test_row_number must be between 0 and {len(tests)-1}")
        sys.exit(1)

    test = tests[test_number]

    print(f"\n{'='*80}")
    print(f"Test #{test_number}")
    print(f"{'='*80}")
    print(f"Question: {test.question}")

    retrieval = evaluate_retrieval(test)

    print("\nRetrieval:")
    print(f"MRR: {retrieval.mrr:.4f}")
    print(f"nDCG: {retrieval.ndcg:.4f}")

    answer_eval, gen_answer, _ = evaluate_answer(test)

    print("\nGenerated Answer:\n", gen_answer)
    print("\nFeedback:\n", answer_eval.feedback)
    print("\nScores:")
    print(f"Accuracy: {answer_eval.accuracy}/5")
    print(f"Completeness: {answer_eval.completeness}/5")
    print(f"Relevance: {answer_eval.relevance}/5")


def main():
    if len(sys.argv) != 2:
        print("Usage: uv run eval.py <test_row_number>")
        sys.exit(1)

    run_cli_evaluation(int(sys.argv[1]))


if __name__ == "__main__":
    main()