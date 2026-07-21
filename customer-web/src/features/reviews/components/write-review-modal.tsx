"use client";

import { useState, useEffect } from "react";
import { X, Star } from "@/shared/icons";
import { submitReview, deleteReview } from "../api";
import type { Review } from "../types";

interface Props {
  productId: number;
  productName: string;
  /** If set, pre-populates the form for editing */
  existingReview?: Review | null;
  onClose: () => void;
  onSuccess: () => void;
}

export function WriteReviewModal({
  productId,
  productName,
  existingReview,
  onClose,
  onSuccess,
}: Props) {
  const [rating, setRating] = useState(existingReview?.rating ?? 0);
  const [hoverRating, setHoverRating] = useState(0);
  const [title, setTitle] = useState(existingReview?.title ?? "");
  const [body, setBody] = useState(existingReview?.body ?? "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Lock body scroll
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (rating === 0) {
      setError("Please select a star rating.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await submitReview(productId, {
        rating,
        title: title.trim() || undefined,
        body: body.trim() || undefined,
      });
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not submit review.");
    } finally {
      setBusy(false);
    }
  };

  const handleDelete = async () => {
    if (!existingReview) return;
    setDeleting(true);
    setError(null);
    try {
      await deleteReview(productId);
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not delete review.");
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 sm:items-center"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="w-full max-w-panel overflow-hidden rounded-t-dialog bg-white sm:rounded-dialog">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-hairline px-lg py-md">
          <h2 className="text-title-lg font-extrabold text-ink">
            {existingReview ? "Edit your review" : "Rate this product"}
          </h2>
          <button
            onClick={onClose}
            aria-label="Close"
            className="flex size-8 items-center justify-center rounded-full transition-colors hover:bg-canvas focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            <X size={18} className="text-muted" aria-hidden />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-lg p-lg">
          {/* Product name */}
          <p className="line-clamp-2 text-body-md text-muted">{productName}</p>

          {/* Star picker */}
          <div>
            <p className="mb-sm text-body-md font-bold text-ink">Your rating</p>
            <div className="flex items-center gap-xs">
              {[1, 2, 3, 4, 5].map((s) => {
                const active = (hoverRating || rating) >= s;
                const isHovered = hoverRating > 0 && hoverRating >= s;
                return (
                  <button
                    key={s}
                    type="button"
                    aria-label={`Rate ${s} star${s > 1 ? "s" : ""}`}
                    onClick={() => setRating(s)}
                    onMouseEnter={() => setHoverRating(s)}
                    onMouseLeave={() => setHoverRating(0)}
                    className="rounded-sm transition-transform duration-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand active:scale-90 hover:scale-110"
                  >
                    <Star
                      size={32}
                      aria-hidden
                      className={
                        active
                          ? isHovered
                            ? "fill-flash-accent text-flash-accent drop-shadow-sm"
                            : "fill-flash-accent text-flash-accent"
                          : "fill-disabled text-disabled"
                      }
                    />
                  </button>
                );
              })}
            </div>
            {(hoverRating || rating) > 0 ? (
              <p className="mt-xs text-body-sm text-muted">
                {
                  ["", "Poor", "Fair", "Good", "Great", "Excellent"][
                    hoverRating || rating
                  ]
                }
              </p>
            ) : null}
          </div>

          {/* Title */}
          <div>
            <label htmlFor="review-title" className="mb-xs block text-body-md font-bold text-ink">
              Title{" "}
              <span className="font-normal text-muted">(optional)</span>
            </label>
            <input
              id="review-title"
              type="text"
              maxLength={120}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Sum up your experience"
              className="w-full rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink placeholder:text-subtle focus:border-brand focus:outline-none focus:ring-1 focus:ring-brand"
            />
          </div>

          {/* Body */}
          <div>
            <label htmlFor="review-body" className="mb-xs block text-body-md font-bold text-ink">
              Review{" "}
              <span className="font-normal text-muted">(optional)</span>
            </label>
            <textarea
              id="review-body"
              maxLength={2000}
              rows={4}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Share details about your purchase…"
              className="w-full resize-none rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink placeholder:text-subtle focus:border-brand focus:outline-none focus:ring-1 focus:ring-brand"
            />
          </div>

          {/* Error */}
          {error ? (
            <p role="alert" className="rounded-sm bg-error-soft px-md py-sm text-body-sm text-error">
              {error}
            </p>
          ) : null}

          {/* Actions */}
          <div className="flex items-center gap-sm">
            <button
              type="submit"
              disabled={busy || rating === 0}
              className="flex h-10 flex-1 items-center justify-center rounded-button bg-brand text-label-md font-extrabold text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:opacity-50"
            >
              {busy ? "Submitting…" : existingReview ? "Update review" : "Submit review"}
            </button>
            {existingReview ? (
              <button
                type="button"
                onClick={handleDelete}
                disabled={deleting}
                className="flex h-10 items-center justify-center rounded-button border border-error px-md text-label-md font-extrabold text-error transition-colors hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error disabled:opacity-50"
              >
                {deleting ? "Deleting…" : "Delete"}
              </button>
            ) : null}
          </div>
        </form>
      </div>
    </div>
  );
}
